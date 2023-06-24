//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "contracts/expander/interfaces/IDAOExpander.sol";
import "contracts/IAutID.sol";

/// @title Voting
/// @notice A simple Voting contract
/// @dev Meant for use with the DAOExpander and AutID contracts
contract Voting {
    IDAOExpander public daoExpander;
    IAutID public autID;

    /// @notice Verifies the caller is a member of the daoExpander contract.
    modifier onlyMember()
    {
        require(daoExpander.isMember(msg.sender), "msg.sender is not a DAO member");
        _;
    }

    /// @notice Sets dependencies
    /// @dev Sets daoExpander and autID
    /// @param _daoExpander the address of the DAOExpander contract
    /// @param _autID the address of the AutID contract
    constructor(IDAOExpander _daoExpander, IAutID _autID)
    {
        daoExpander = _daoExpander;
        autID = _autID;

        // Since `daoExpander` is not set before contract deployment,
        // we can't use the onlyMember modifier here. So we just repeat the require.
        require(daoExpander.isMember(msg.sender), "Can only be deployed by DAO member");
    }

    // 2D mapping to track whether a given user has voted on a given proposal
    mapping(uint => mapping(address => bool)) hasVoted;

    // Struct to track all needed info about a given proposal
    // (aside from the hasVoted info above)
    struct Proposal {
        uint startTime;
        uint endTime;
        string cid;
        uint yeaCount;
        uint nayCount;
    }

    // Dynamic array of `Proposal`s
    Proposal[] proposals;

    /// @notice Internal function to create proposal
    /// @dev Adds a new Proposal to the proposals array and populates needed info
    /// @return newPropID The id (aka array position) of the new proposal
    function _createProposal(uint _startTime, uint _endTime, string calldata _cid)
        internal
        returns (uint)
    {
        uint newPropID = proposals.length;

        // push a zero-state `Proposal`
        proposals.push();

        // Get pointer to new proposal and simply pass in arguments
        Proposal storage newProposal = proposals[newPropID];
        newProposal.startTime = _startTime;
        newProposal.endTime = _endTime;
        newProposal.cid = _cid;
        // yeaCount and nayCount are initialized at 0 already, which is what we want

        return newPropID;
    }

    /// @notice External function to create proposal
    /// @dev Checks time boundary conditions before creating the proposal via the above internal function
    /// @return newPropID The id (aka array position) of the new proposal
    function createProposal(uint _startTime, uint _endTime, string calldata _cid)
        public
        onlyMember
        returns (uint)
    {
        require(_startTime > block.timestamp, "Proposal cannot start in the past");
        require(_endTime > _startTime, "End time must be after start time");

        uint id = _createProposal(_startTime, _endTime, _cid);
        return id;
    }

    /// @notice Internal function that calculates weight given a member
    /// @dev determines the voting weight of the member based on their AutID role within the daoExpander
    /// @return weight the uint value or "weight" of the vote
    function _getWeightForMember(address member)
        internal
        view
        returns (uint)
    {
        uint role = autID.getMembershipData(member, address(daoExpander)).role;
        if (role == 1)
        {
            return 10;
        }
        else if (role == 2)
        {
            return 20;
        }
        else if (role == 3)
        {
            return 35;
        }
        else {
            revert ("that role shouldn't be possible!");
        }
    }

    /// @notice vote yes or no on a particular proposal
    /// @dev Reverts if the proposal is not active
    /// @dev Reverts if the user is not a member
    /// @dev Reverts if the user has already voted on this proposal
    function vote(uint proposalID, bool isSupporting)
        external
        onlyMember
    {
        // get pointer to proposal in question
        Proposal storage proposal = proposals[proposalID];

        require(block.timestamp >= proposal.startTime, "Proposal voting has not yet started.");
        require(block.timestamp < proposal.endTime, "Proposal voting has ended.");
        require(!hasVoted[proposalID][msg.sender], "You already voted on this proposal.");

        uint voteWeight = _getWeightForMember(msg.sender);
        
        // Update proposal's record depending on `isSupporting`
        if (isSupporting)
        {
            proposal.yeaCount += voteWeight;
        }
        else
        {
            proposal.nayCount += voteWeight;
        }

        hasVoted[proposalID][msg.sender] = true;
    }

    /// @notice Get `Proposal` struct given an ID
    /// @dev Will revert if `id` is out of range
    /// @return proposal the proposal corresponding to `id`
    function getProposal(uint id)
        external
        view
        returns (Proposal memory)
    {
        return proposals[id];
    }

    /// @notice Internal function to determine whether a given proposal is active
    /// @return true if the proposal is active (startTime <= now <= endTime); false otherwise
    function proposalIsActive(Proposal storage proposal)
        internal
        view
        returns (bool)
    {
        return (block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime);
    }

    /// @notice Builds and returns a list of IDs of all active proposals
    /// @dev Very gas inefficient. In a well-designed dapp, the interface would be doing more of this work.
    /// @return activeProposalIDsTrimmed An array of all proposals that are "active" (see above function).
    function getActiveProposalIDs()
        view
        external
        returns (uint[] memory)
    {
        // We first initialize an array to hold the IDs of any active props.
        // We initialize it with length=proposals.length,
        // as we cannot dynamically size (and thus cannot push to) memory arrays,
        // and we know that it will be at most as big as proposals.
        uint[] memory activeProposalIDs = new uint[](proposals.length);

        uint numActivePropsFound = 0;
        for (uint i=0; i<proposals.length; i++)
        {
            if (proposalIsActive(proposals[i]))
            {
                activeProposalIDs[numActivePropsFound] = i;
                numActivePropsFound ++;
            }
        }

        // we use the `numActiveProposalsFound` to create a new array sized correctly
        uint[] memory activeProposalIDsTrimmed = new uint[](numActivePropsFound);
        // and copy the IDs from the oversized array into the appropriately-sized array
        for (uint i=0; i<numActivePropsFound; i++)
        {
            activeProposalIDsTrimmed[i] = activeProposalIDs[i];
        }

        return activeProposalIDsTrimmed;
    }
}