// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {Dispatcher, Payments} from './base/Dispatcher.sol';
// import {RewardsCollector} from './base/RewardsCollector.sol';
import {RouterParameters, RouterImmutables} from './base/RouterImmutables.sol';
import {Constants} from './libraries/Constants.sol';
import {Commands} from './libraries/Commands.sol';
import {IUniversalRouterV1} from './interfaces/IUniversalRouterV1.sol';
import {ReentrancyLock} from './base/ReentrancyLock.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
// import {Ownable2StepUpgradeable} from '@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IFlashLoanReceiver} from './interfaces/external/IAave.sol';
import {SafeTransferLib} from '../libraries/SafeTransferLib.sol';
import {IAaveViewer} from './modules/aave/AaveAdapter.sol';
import {ModuleParameters} from './base/ModuleImmutables.sol';

// RouterImmutables,
contract UniversalRouterV1 is
    IUniversalRouterV1,
    Dispatcher,
    // RewardsCollector,
    ReentrancyLock,
    UUPSUpgradeable,
    // Ownable2StepUpgradeable,
    Ownable2Step,
    IFlashLoanReceiver
{
    using SafeTransferLib for address;
    error AmountOutTooLow();

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    constructor(RouterParameters memory params, ModuleParameters memory mparams) Dispatcher(params, mparams) {}

    // function initialize() public initializer {
    //     __Ownable2Step_init();
    // }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // function version() public pure returns (string memory) {
    //     return '1.0';
    // }

    // Lending pools should be added to the router before they are used.
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //
        if (!IAaveViewer(AAVE_VIEWER).lendingPools(msg.sender)) revert('AaveInvalidLendingPool');
        if (address(this) != initiator) revert('AaveInvalidInitiator');

        if (params.length > 0) {
            (bytes memory commands, bytes[] memory inputs) = abi.decode(params, (bytes, bytes[]));
            // internalExecute(commands, inputs);
        }

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + premiums[i];
            assets[i].safeApprove(msg.sender, 0);
            assets[i].safeApprove(msg.sender, amountOwing);
        }
        return true;
    }

    // /// @inheritdoc IUniversalRouterV1
    // function conditionalAggregate(
    //     bytes calldata mustCmds,
    //     bytes[] calldata mustData,
    //     bytes calldata conditionalCmds,
    //     bytes[] calldata conditionalData,
    //     uint256 deadline,
    //     uint8 condition,
    //     bytes calldata conditionParams
    // ) external payable override checkDeadline(deadline) isNotLocked {
    //     bool last;
    //     last = conditionalExecute(mustCmds, mustData, condition, conditionParams);

    //     // For Call array mustCalls,
    //     // Each mustCall
    //     // target is address(this)
    //     // callData is encoded data whose function selector is execute and it contains each DEX aggregator path info
    //     // callData is passed to the multicall contract

    //     if (last) {
    //         if (conditionalCmds.length > 0) {
    //             execute(conditionalCmds, conditionalData);

    //             // For Call array conditionalCalls,
    //             // Each conditional call[i]
    //             // target is address(this)
    //             // callData is encoded data whose function selector is tryAggregate and
    //             // parameters are requireSuccess is true and calls includes making loan and repayment at the edge encoded in bytes
    //             // calls params are encoded data whose function selector is execute and it contains each arbitrage path
    //         }
    //     }
    // }

    /// TODO checkBefore / checkAfter
    // function conditionalExecute(
    //     bytes calldata commands,
    //     bytes[] calldata inputs,
    //     uint8 condition,
    //     bytes calldata conditionParams
    // ) internal returns (bool last) {
    //     if (commands.length > 0) {
    //         bytes memory bfStandard = checkBefore(condition, conditionParams);
    //         execute(commands, inputs);
    //         (bool success, bytes memory outputs) = checkAfter(condition, conditionParams, bfStandard);
    //         if (!success) {
    //             revert ConditionFailed(outputs);
    //         }
    //         (, , last) = abi.decode(outputs, (uint256, uint256, bool));
    //     }
    // }

    /// @inheritdoc IUniversalRouterV1
    // function execute(
    //     bytes calldata commands,
    //     bytes[] calldata inputs,
    //     uint256 deadline
    // ) external payable override checkDeadline(deadline) {
    //     execute(commands, inputs);
    // }

    /// @inheritdoc IUniversalRouterV1
    function execute(bytes calldata commands, bytes[] calldata inputs) public payable override isNotLocked {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands; ) {
            bytes1 command = commands[commandIndex];

            bytes memory input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({commandIndex: commandIndex, message: output});
            }

            unchecked {
                commandIndex++;
            }
        }
    }

    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        uint256[] calldata initWeights,
        uint256[][][] calldata weights
    )
        public
        payable
        isNotLocked
        checkDeadline(deadline)
        returns (
            address inputToken,
            address outputToken,
            uint256 amountOut
        )
    {
        uint256 totalCmds;
        for (uint256 i; i < weights.length; i++) {
            for (uint256 j; j < weights[i].length; j++) {
                totalCmds += weights[i][j].length;
            }
        }
        if (inputs.length != commands.length || totalCmds != commands.length || weights.length != initWeights.length)
            revert LengthMismatch();

        (inputToken, outputToken, amountOut) = dispatchWith3DWeights(commands, inputs, amountIn, initWeights, weights);
        if (amountOut < minAmountOut) revert AmountOutTooLow();
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }

    // function internalExecute(bytes memory commands, bytes[] memory inputs) internal {
    //     bool success;
    //     bytes memory output;
    //     uint256 numCommands = commands.length;
    //     if (inputs.length != numCommands) revert LengthMismatch();

    //     // loop through all given commands, execute them and pass along outputs as defined
    //     for (uint256 commandIndex = 0; commandIndex < numCommands; ) {
    //         bytes1 command = commands[commandIndex];

    //         bytes memory input = inputs[commandIndex];

    //         (success, output) = dispatch(command, input);

    //         if (!success && successRequired(command)) {
    //             revert ExecutionFailed({commandIndex: commandIndex, message: output});
    //         }

    //         unchecked {
    //             commandIndex++;
    //         }
    //     }
    // }

    // To receive ETH from WETH and NFT protocols
    receive() external payable {}
}
