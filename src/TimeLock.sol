// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // mintDelay is how long one has to wait before executing
    // proposers is the list of addresses that can propose
    // executors is the list of addresses that can execute
    constructor(
        uint256 mintDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(mintDelay, proposers, executors, msg.sender) {}
}
