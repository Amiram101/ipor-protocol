// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../libraries/errors/IporErrors.sol";

/// @title Extended version of OpenZeppelin OwnableUpgradeable contract with appointed owner
abstract contract IporOwnableUpgradeable is OwnableUpgradeable {
    address private _appointedOwner;

    /// @notice Emitted when account is appointed to transfer ownership
    /// @param appointedOwner Address of appointed owner
    event AppointedToTransferOwnership(address indexed appointedOwner);

    modifier onlyAppointedOwner() {
        require(_appointedOwner == _msgSender(), IporErrors.SENDER_NOT_APPOINTED_OWNER);
        _;
    }

    /// @notice Oppoint account to transfer ownership
    /// @param appointedOwner Address of appointed owner
    function transferOwnership(address appointedOwner) public override onlyOwner {
        require(appointedOwner != address(0), IporErrors.WRONG_ADDRESS);
        _appointedOwner = appointedOwner;
        emit AppointedToTransferOwnership(appointedOwner);
    }

    /// @notice Confirm transfer ownership
    /// @dev This is real transfer ownership in second step by appointed account
    function confirmTransferOwnership() external onlyAppointedOwner {
        _appointedOwner = address(0);
        _transferOwnership(_msgSender());
    }

    /// @notice Renounce ownership
    function renounceOwnership() public virtual override onlyOwner {
        _transferOwnership(address(0));
        _appointedOwner = address(0);
    }
}
