// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.20;

import "../../interfaces/IIporContractCommonGov.sol";
import "../../libraries/errors/AmmErrors.sol";
import "../../libraries/errors/IporErrors.sol";
import "../../libraries/IporContractValidator.sol";
import "../../security/PauseManager.sol";
import "../../amm/spread/SpreadStorageLibs.sol";

/// @title Contract responsible for managing access control for the Spread Router
contract SpreadAccessControl is IIporContractCommonGov {
    using IporContractValidator for address;

    event AppointedToTransferOwnership(address indexed appointedOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address internal immutable _iporProtocolRouter;

    constructor(address iporProtocolRouter) {
        _iporProtocolRouter = iporProtocolRouter.checkAddress();
    }

    /// @dev Throws an error if called by any account other than the owner.
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @dev Throws an error if called by any account other than the appointed owner.
    modifier onlyAppointedOwner() {
        require(
            SpreadStorageLibs.getAppointedOwner().appointedOwner == msg.sender,
            IporErrors.SENDER_NOT_APPOINTED_OWNER
        );
        _;
    }

    /// @dev Throws and error if called by any account other than the pause guardian.
    modifier onlyPauseGuardian() {
        require(PauseManager.isPauseGuardian(msg.sender), IporErrors.CALLER_NOT_GUARDIAN);
        _;
    }

    /// @notice Returns the address of the contract's owner.
    /// @return The address of the contract's owner.
    function owner() external view returns (address) {
        return SpreadStorageLibs.getOwner().owner;
    }

    /// @notice Transfers the ownership of the contract to a new appointed owner.
    /// @param newAppointedOwner The address of the new appointed owner.
    /// @dev Only the current contract owner can call this function.
    function transferOwnership(address newAppointedOwner) public onlyOwner {
        require(newAppointedOwner != address(0), IporErrors.WRONG_ADDRESS);
        SpreadStorageLibs.AppointedOwnerStorage storage appointedOwnerStorage = SpreadStorageLibs.getAppointedOwner();
        appointedOwnerStorage.appointedOwner = newAppointedOwner;
        emit AppointedToTransferOwnership(newAppointedOwner);
    }

    /// @notice Confirms the transfer of the ownership by the appointed owner.
    /// @dev Only the appointed owner can call this function.
    function confirmTransferOwnership() public onlyAppointedOwner {
        SpreadStorageLibs.AppointedOwnerStorage storage appointedOwnerStorage = SpreadStorageLibs.getAppointedOwner();
        appointedOwnerStorage.appointedOwner = address(0);
        _transferOwnership(msg.sender);
    }

    /// @notice Renounces the ownership of the contract.
    /// @dev Only the contract owner can call this function.
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
        SpreadStorageLibs.AppointedOwnerStorage storage appointedOwnerStorage = SpreadStorageLibs.getAppointedOwner();
        appointedOwnerStorage.appointedOwner = address(0);
    }

    /// @notice Pauses the contract.
    /// @dev Only the pause guardian can call this function.
    function pause() external override onlyPauseGuardian {
        _pause();
    }

    /// @notice Unpauses the contract.
    /// @dev Only the contract owner can call this function.
    function unpause() external override onlyOwner {
        SpreadStorageLibs.getPaused().value = 0;
    }

    /// @notice Returns the current pause status of the contract.
    /// @return The pause status represented as a uint256 value (0 for not paused, 1 for paused).
    function paused() external view returns (uint256) {
        return uint256(SpreadStorageLibs.getPaused().value);
    }

    /// @notice Checks if an address is a pause guardian.
    /// @param account The address to be checked.
    /// @return A boolean indicating whether the address is a pause guardian (true) or not (false).
    function isPauseGuardian(address account) external view override returns (bool) {
        return PauseManager.isPauseGuardian(account);
    }

    /// @notice Adds a new pause guardian to the contract.
    /// @param guardians The addresses of the new pause guardians.
    /// @dev Only the contract owner can call this function.
    function addPauseGuardians(address[] calldata guardians) external override onlyOwner {
        PauseManager.addPauseGuardians(guardians);
    }

    /// @notice Removes a pause guardian from the contract.
    /// @param guardians The list addresses of the pause guardians to be removed.
    /// @dev Only the contract owner can call this function.
    function removePauseGuardians(address[] calldata guardians) external override onlyOwner {
        PauseManager.removePauseGuardians(guardians);
    }

    /// @dev Internal function to check if the sender is the AMM address.
    function _onlyIporProtocolRouter() internal view {
        require(msg.sender == _iporProtocolRouter, AmmErrors.SENDER_NOT_AMM);
    }

    function _whenNotPaused() internal view {
        require(uint256(SpreadStorageLibs.getPaused().value) == 0, IporErrors.METHOD_PAUSED);
    }

    /// @dev Internal function to check if the sender is the contract owner.
    function _onlyOwner() internal view {
        require(SpreadStorageLibs.getOwner().owner == msg.sender, IporErrors.CALLER_NOT_OWNER);
    }

    function _pause() internal {
        SpreadStorageLibs.getPaused().value = 1;
    }

    /**
     * @dev Transfers the ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        SpreadStorageLibs.OwnerStorage storage ownerStorage = SpreadStorageLibs.getOwner();
        address oldOwner = ownerStorage.owner;
        ownerStorage.owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
