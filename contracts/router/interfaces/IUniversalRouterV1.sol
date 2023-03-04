// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

// import {IRewardsCollector} from './IRewardsCollector.sol';

interface IUniversalRouterV1 is IERC721Receiver, IERC1155Receiver {
    /// @notice Thrown when a required command has failed
    error ExecutionFailed(uint256 commandIndex, bytes message);

    /// @notice Thrown when attempting to send ETH directly to the contract
    error ETHNotAccepted();

    /// @notice Thrown executing commands with an expired deadline
    error TransactionDeadlinePassed();

    /// @notice Thrown executing commands with an expired deadline
    error LengthMismatch();

    // struct Call {
    //     bytes1 command;
    //     bytes callData;
    // }

    /// @notice Executes encoded commands along with provided inputs. In mustCalls, If specified condition is not met with the result, revert transaction.
    /// In conditionalCalls, Only if the result of command is met to each specified condition, execute transaction.
    /// @param mustCmds A set of concatenated DEX aggregator path execution commands, each 1 byte in length (see Commands.sol) f should be set to 1 (require success)
    /// @param mustData An array of byte strings containing abi encoded inputs for each must command
    /// @param conditionalCmds A set of concatenated path using external assets like flashloan/flashswap/vaults, each 1 byte in length (see Commands.sol)
    /// All repay would be done and the result token should be transferred to recipient
    /// @param conditionalData An array of byte strings containing abi encoded inputs for each conditional command
    /// @param deadline The deadline by which the transaction must be executed
    /// @param condition The condition case which mustCalls should meet to execute commands
    /// @param conditionParams The condition case which quote should meet to execute commands
    // function conditionalAggregate(
    //     bytes calldata mustCmds,
    //     bytes[] calldata mustData,
    //     bytes calldata conditionalCmds,
    //     bytes[] calldata conditionalData,
    //     uint256 deadline,
    //     uint8 condition,
    //     bytes calldata conditionParams
    // ) external payable;

    // /// @notice Executes encoded commands along with provided inputs. Reverts if deadline has expired.
    // /// @param commands A set of concatenated commands, each 1 byte in length
    // /// @param inputs An array of byte strings containing abi encoded inputs for each command
    // /// @param deadline The deadline by which the transaction must be executed
    // function execute(
    //     bytes calldata commands,
    //     bytes[] calldata inputs,
    //     uint256 deadline
    // ) external payable;

    /// @notice Executes encoded commands along with provided inputs.
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}
