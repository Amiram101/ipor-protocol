// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/interfaces/draft-IERC1822Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1967Upgradeable.sol";
import "./IIporContractCommonGov.sol";
import "./IProxyImplementation.sol";
import "./IAmmCloseSwapService.sol";
import "./IAmmCloseSwapLens.sol";
import "../amm/spread/ISpread28Days.sol";
import "../amm/spread/ISpread28DaysLens.sol";
import "../amm/spread/ISpread60Days.sol";
import "../amm/spread/ISpread60DaysLens.sol";
import "../amm/spread/ISpread90Days.sol";
import "../amm/spread/ISpread90DaysLens.sol";
import "../amm/spread/ISpreadStorageLens.sol";

/// @title Interface for interaction with IPOR SpreadRouter.
/// Interface combines all IPOR SpreadRouter interfaces and supported services and lenses by router.
interface ISpreadRouter is
    IERC1822ProxiableUpgradeable,
    IERC1967Upgradeable,
    IIporContractCommonGov,
    IProxyImplementation,
    IAmmCloseSwapService,
    IAmmCloseSwapLens,
    ISpread28Days,
    ISpread28DaysLens,
    ISpread60Days,
    ISpread60DaysLens,
    ISpread90Days,
    ISpread90DaysLens,
    ISpreadStorageLens
{

}
