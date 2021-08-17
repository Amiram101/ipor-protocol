// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.4 <0.9.0;

import {DataTypes} from '../libraries/types/DataTypes.sol';
import {Errors} from '../Errors.sol';
import {Constants} from '../libraries/Constants.sol';
import {AmmMath} from '../libraries/AmmMath.sol';

library IporLogic {

    function accrueIbtPrice(DataTypes.IPOR memory ipor, uint256 accrueTimestamp) public pure returns (uint256){
        return ipor.quasiIbtPrice + (ipor.indexValue * (accrueTimestamp - ipor.blockTimestamp));
    }
}