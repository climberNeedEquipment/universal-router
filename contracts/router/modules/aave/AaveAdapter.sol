// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {RouterImmutables, RouterParameters} from '../../base/RouterImmutables.sol';
import {Payments} from '../Payments.sol';
import {Permit2Payments} from '../Permit2Payments.sol';
import {Constants} from '../../libraries/Constants.sol';
import {SafeCastLib} from '../../../libraries/SafeCastLib.sol';
import {UniERC20} from '../../../libraries/UniERC20.sol';
import {IPool} from '../../interfaces/external/IAave.sol';
import {IUniversalRouterV1} from '../../interfaces/IUniversalRouterV1.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

interface IAaveViewer {
    function lendingPools(address) external view returns (bool);
}

/// @title Router for Aave v2 Trades
contract AaveAdapter is RouterImmutables, Permit2Payments {
    using SafeCastLib for uint256;
    using SafeCastLib for int256;
    using UniERC20 for address;

    constructor(RouterParameters memory params) RouterImmutables(params) {}

    function aaveExecute(
        address lendingPool,
        uint8 functionVersion,
        bytes memory executeParams,
        address payer
    )
        public
        returns (
            address inputToken,
            address outputToken,
            uint256 amountOut
        )
    {
        if (!IAaveViewer(AAVE_VIEWER).lendingPools(lendingPool)) revert('AaveInvalidLendingPool');
        if (functionVersion == 8) {
            // flashloan let's assume we use only one asset for flashloan
            (address[] memory assets, uint256[] memory amounts, bytes memory swapDes) = abi.decode(
                executeParams,
                (address[], uint256[], bytes)
            );
            uint256[] memory modes = new uint256[](assets.length);
            uint256 bfBalance = assets[0].uniBalanceOf(address(this));
            IPool(lendingPool).flashLoan(address(this), assets, amounts, modes, address(this), swapDes, 0);
            uint256 afBalance = assets[0].uniBalanceOf(address(this));
            amountOut = afBalance >= bfBalance ? afBalance - bfBalance : 0;
            inputToken = assets[0];
            outputToken = assets[0];
        } else if (functionVersion == 1) {
            // deposit
            // asset should be underlying asset
            // amount should be underlying amount to deposit
            (address asset, address aToken, address recipient, uint256 amount) = abi.decode(
                executeParams,
                (address, address, address, uint256)
            );
            if (amount != Constants.ALREADY_PAID) {
                payOrPermit2Transfer(asset, payer, address(this), amount);
            }
            asset.uniApproveMax(lendingPool, amount);
            IPool(lendingPool).deposit(asset, amount, recipient, 0);
            amountOut = amount;
            inputToken = asset;
            outputToken = aToken;
        } else if (functionVersion == 2) {
            // withdraw
            // asset should be underlying asset
            // amount should be aToken amount to pay for withdrawal
            //
            (address asset, address aToken, address recipient, uint256 amount) = abi.decode(
                executeParams,
                (address, address, address, uint256)
            );

            if (amount != Constants.ALREADY_PAID) {
                payOrPermit2Transfer(aToken, payer, address(this), amount);
            }
            uint256 bfBalance = asset.uniBalanceOf(address(this));
            IPool(lendingPool).withdraw(asset, type(uint256).max, recipient);
            amountOut = asset.uniBalanceOf(address(this)) - bfBalance;
            inputToken = aToken;
            outputToken = asset;
        } else if (functionVersion == 3) {
            // borrow
            (address asset, uint256 amount, uint256 rateMode) = abi.decode(executeParams, (address, uint256, uint256));
            if (amount != Constants.ALREADY_PAID) {
                payOrPermit2Transfer(asset, payer, address(this), amount);
            }
            IPool(lendingPool).borrow(asset, amount, rateMode, 0, msg.sender);
            amountOut = amount;
        } else if (functionVersion == 4) {
            // repay
            (address asset, uint256 amount, uint256 rateMode) = abi.decode(executeParams, (address, uint256, uint256));

            IPool(lendingPool).repay(asset, amount, rateMode, msg.sender);
        } else if (functionVersion == 5) {
            // swap borrow rate mode
            (address asset, uint256 rateMode) = abi.decode(executeParams, (address, uint256));
            IPool(lendingPool).swapBorrowRateMode(asset, rateMode);
        } else if (functionVersion == 6) {
            // Enable/disable their deposits as collateral rebalance stable rate borrow positions
            (address asset, bool useAsCollateral) = abi.decode(executeParams, (address, bool));
            IPool(lendingPool).setUserUseReserveAsCollateral(asset, useAsCollateral);
        } else if (functionVersion == 7) {
            // liquidation call
            (address collateralAsset, address debtAsset, address user, uint256 debtToCover) = abi.decode(
                executeParams,
                (address, address, address, uint256)
            );
            IPool(lendingPool).liquidationCall(collateralAsset, debtAsset, user, debtToCover, false);
        } else {
            revert('AaveInvalidParams');
        }
    }
}
