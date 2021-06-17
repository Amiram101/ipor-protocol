// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.4 <0.9.0;

import {Errors} from '../Errors.sol';
import './IporOracleStorage.sol';
import "../interfaces/IIporOracle.sol";
import {DataTypes} from '../libraries/types/DataTypes.sol';


/**
 * @title IPOR Index Oracle Contract
 *
 * @author IPOR Labs
 */
contract IporOracle is IporOracleV1Storage, IIporOracle {

    /// @notice event emitted when IPOR Index is updated by Updater
    event IporIndexUpdate(string ticker, uint256 value, uint256 interestBearingToken, uint256 date);

    /// @notice event emitted when IPOR Index Updater is added by Admin
    event IporIndexUpdaterAdd(address _updater);

    /// @notice event emitted when IPOR Index Updater is removed by Admin
    event IporIndexUpdaterRemove(address _updater);

    constructor() {
        admin = msg.sender;
    }

    /**
     * @notice Returns IPOR Index value for all assets supported by IPOR Oracle
     * @return List of assets with calculated IPOR Index in current moment.
     *
     */
    function getIndexes() external view returns (DataTypes.IporIndex[] memory) {
        DataTypes.IporIndex[] memory _indexes = new DataTypes.IporIndex[](tickers.length);
        for (uint256 i = 0; i < tickers.length; i++) {
            _indexes[i] = DataTypes.IporIndex(
                indexes[tickers[i]].ticker,
                indexes[tickers[i]].value,
                indexes[tickers[i]].interestBearingToken,
                indexes[tickers[i]].date
            );
        }
        return _indexes;
    }


    /**
     * @notice Update IPOR index for specific asset
     * @param _ticker The ticker of the asset
     * @param _value The value of IPOR for particular asset
     *
     */
    function updateIndex(string memory _ticker, uint256 _value, uint256 _interestBearingToken) public onlyUpdater {

        bool tickerExists = false;
        bytes32 _tickerHash = keccak256(abi.encodePacked(_ticker));

        for (uint256 i = 0; i < tickers.length; i++) {
            if (tickers[i] == _tickerHash) {
                tickerExists = true;
            }
        }

        if (tickerExists == false) {
            tickers.push(_tickerHash);
        }

        uint256 updateDate = block.timestamp;
        indexes[_tickerHash] = DataTypes.IporIndex(_ticker, _value, _interestBearingToken, updateDate);
        emit IporIndexUpdate(_ticker, _value, _interestBearingToken, updateDate);
    }


    /**
     * @notice Return IPOR index for specific asset
     * @param _ticker The ticker of the asset
     * @return value then value of IPOR Index for asset with ticker name _ticker
     * @return interestBearingToken interest bearing token in this particular moment
     * @return date date when IPOR Index was calculated for asset
     *
     */
    function getIndex(string memory _ticker) external view  override(IIporOracle)
        returns (uint256 value, uint256 interestBearingToken, uint256 date) {
        bytes32 _tickerHash = keccak256(abi.encodePacked(_ticker));
        DataTypes.IporIndex storage _iporIndex = indexes[_tickerHash];
        return (
            value = _iporIndex.value,
            interestBearingToken = _iporIndex.interestBearingToken,
            date = _iporIndex.date
        );
    }



    /**
     * @notice Add updater address to list of updaters who are authorized to actualize IPOR Index in Oracle
     * @param _updater Address of new updater
     *
     */
    function addUpdater(address _updater) public onlyAdmin {
        bool updaterExists = false;
        for (uint256 i; i < updaters.length; i++) {
            if (updaters[i] == _updater) {
                updaterExists = true;
            }
        }
        if (updaterExists == false) {
            updaters.push(_updater);
            emit IporIndexUpdaterAdd(_updater);
        }
    }

    /**
     * @notice Return list of updaters who are authorized to actualize IPOR Index in Oracle
     * @return list of updater addresses who are authorized to actualize IPOR Index in Oracle
     *
     */
    function getUpdaters() external view returns (address[] memory) {
        return updaters;
    }


    /**
     * @notice Remove specific address from list of IPOR Index authorized updaters
     * @param _updater address which will be removed from list of IPOR Index authorized updaters
     */
    function removeUpdater(address _updater) public onlyAdmin {

        for (uint256 i; i < updaters.length; i++) {
            if (updaters[i] == _updater) {
                delete updaters[i];
                emit IporIndexUpdaterRemove(_updater);
            }
        }
    }


    /**
     * @notice Modifier which checks if caller is authorized to update IPOR Index
     */
    modifier onlyUpdater() {
        bool allowed = false;
        for (uint256 i = 0; i < updaters.length; i++) {
            if (updaters[i] == msg.sender) {
                allowed = true;
            }
        }
        require(allowed == true, Errors.CALLER_NOT_IPOR_ORACLE_UPDATER);
        _;
    }

    /**
     * @notice Modifier which checks if caller is admin for this contract
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, Errors.CALLER_NOT_IPOR_ORACLE_ADMIN);
        _;
    }

}