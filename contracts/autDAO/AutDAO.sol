//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../daoUtils/abstracts/DAOUrls.sol";
import "../daoUtils/abstracts/DAOMarket.sol";
import "../daoUtils/abstracts/DAOMembers.sol";
import "../daoUtils/abstracts/DAOModules.sol";
import "../daoUtils/abstracts/DAOMetadata.sol";
import "../daoUtils/abstracts/AutIDAddress.sol";
import "../daoUtils/abstracts/DAOCommitment.sol";
import "../daoUtils/abstracts/DAOInteractions.sol";

import "../modules/interfaces/modules/onboarding/OnboardingModule.sol";
import "./interfaces/IAutDAO.sol";

/// @title AutDAO
/// @notice
/// @dev
contract AutDAO is
    DAOMembers,
    DAOInteractions,
    DAOMetadata,
    DAOUrls,
    DAOMarket,
    DAOModules,
    DAOCommitment,
    IAutDAO
{
    address private deployer;
    address private onboardingAddr;

    /// @notice Sets the initial details of the DAO
    /// @dev all parameters are required.
    /// @param _deployer the address of the DAOTypes.sol contract
    /// @param _autAddr the address of the DAOTypes.sol contract
    /// @param _market one of the 3 markets
    /// @param _metadata url with metadata of the DAO - name, description, logo
    /// @param _commitment minimum commitment that the DAO requires
    constructor(
        address _deployer,
        IAutID _autAddr,
        uint256 _market,
        string memory _metadata,
        uint256 _commitment,
        address _pluginRegistry
    ) {
        deployer = _deployer;
        isAdmin[_deployer] = true;
        admins.push(_deployer);

        super._setMarket(_market);
        super._setAutIDAddress(_autAddr);
        super._setCommitment(_commitment);
        super._setMetadataUri(_metadata);
        super._deployInteractions();
        super._setPluginRegistry(_pluginRegistry);
    }

    function setOnboardingStrategy(address onboardingPlugin) public onlyAdmin {
        onboardingAddr = onboardingPlugin;
    }

    function setMetadataUri(string memory metadata) public override onlyAdmin {
        _setMetadataUri(metadata);
    }

    function addURL(string memory url) external override onlyAdmin {
        _addURL(url);
    }

    function removeURL(string memory url) external override onlyAdmin {
        _removeURL(url);
    }

    function setCommitment(uint256 commitment) external override onlyAdmin {
        _setCommitment(commitment);
    }

    function canJoin(address member, uint256 role)
        external
        view
        override
        returns (bool)
    {
        if (onboardingAddr == address(0)) return true;
        if (
            onboardingAddr != address(0) &&
            OnboardingModule(onboardingAddr).isActive()
        ) return false;
        else
            return OnboardingModule(onboardingAddr).isOnboarded(member, role);
    }
}
