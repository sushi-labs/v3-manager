// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.8.0;

import "interfaces/IUniswapV3Factory.sol";
import "interfaces/IUniswapV3Pool.sol";
import "./Auth.sol";

/// @title V3Manager for UniswapV3Factory
/// @notice This contract is used to create fee tiers, set protocol fee on pools, and collect fees from pools
/// @dev Uses Auth contract for owner and trusted operators to guard functions
contract V3Manager is Auth {
  IUniswapV3Factory public factory;
  address public maker;
  uint8 public protocolFee;

  constructor(
    address _operator,
    address _factory,
    address _maker,
    uint8 _protocolFee
  ) Auth(_operator) {
    // initial owner is msg.sender
    factory = IUniswapV3Factory(_factory);
    maker = _maker;
    protocolFee = _protocolFee;
  }

  /// @notice Creates a new fee tier with passed tickSpacing
  /// @dev will revert on factory contract if inputs invalid
  /// @param fee The fee amount to enable, denominated in hundreths of a bip
  /// @param tickSpacing The spacing between ticks to be enforced for all pools created with the given fee amount
  function createFeeTier(uint24 fee, int24 tickSpacing) external onlyOwner {
    IUniswapV3Factory(factory).enableFeeAmount(fee, tickSpacing);
  }

  /// @notice transfer ownership of the factory contract
  /// @param newOwner The newOwner address to set on the factory contract
  function setFactoryOwner(address newOwner) external onlyOwner {
    IUniswapV3Factory(factory).setOwner(newOwner);
  }

  /// @notice Sets the protocol fee to be used for all pools
  /// @dev must apply to each pool everytime it's changed
  /// @param _protocolFee The protocol fee to be used for all pools
  function setProtocolFee(uint8 _protocolFee) external onlyOwner {
    protocolFee = _protocolFee;
  }

  /// @notice Sets the maker contract to be used for collecting fees
  /// @dev Where all fees will be sent to when collected
  /// @param _maker The address of the maker contract
  function setMaker(address _maker) external onlyOwner {
    maker = _maker;
  }

  /// @notice Applies the protocol fee to all pools passed
  /// @dev must be called for each pool, after protocolFee is updated
  /// @param pools The addresses of the pools to apply the protocol fee to
  function applyProtocolFee(address[] calldata pools) external onlyTrusted {
    for (uint256 i = 0; i < pools.length; i++) {
      IUniswapV3Pool pool = IUniswapV3Pool(pools[i]);
      pool.setFeeProtocol(protocolFee, protocolFee);
    }
  } 

  /// @notice Collects fees from pools passed
  /// @dev Will call collectProtocol on each pool address, sending fees to maker contract that is set
  /// @param pools The addresses of the pools to collect fees from
  function collectFees(address[] calldata pools) external onlyTrusted {
    for (uint256 i = 0; i < pools.length; i++) {
      IUniswapV3Pool pool = IUniswapV3Pool(pools[i]);
      (uint128 amount0, uint128 amount1) = pool.protocolFees();
      pool.collectProtocol(maker, amount0, amount1);
    }
  }

  /// @notice Available function in case we need to do any calls that aren't supported by the contract (unwinding lp positions, etc.)
  /// @dev can only be called by owner
  /// @param to The address to send the call to
  /// @param _value The amount of eth to send with the call
  /// @param data The data to be sent with the call
  function doAction(address to, uint256 _value, bytes memory data) onlyOwner external {
    (bool success, ) = to.call{value: _value}(data);
    require(success);
  }
}