//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "contracts/expander/interfaces/IDAOExpander.sol";

contract Voting {
    IDAOExpander public dao;

    modifier onlyMember()
    {
        require(dao.isMember(msg.sender), "msg.sender is not a DAO member");
        _;
    }

    constructor(IDAOExpander _dao)
    {
        dao = _dao;

        // can't use the onlyMember modifier here as dao is not set before constructor start, so we'll just repeat the require
        require(dao.isMember(msg.sender), "Can only be deployed by DAO member");
    }

    mapping(uint => mapping(address => bool)) hasVoted;

    struct Proposal {
        uint startTime;
        uint endTime;
        string cid;
        uint yeaCount;
        uint nayCount;
    }

    Proposal[] proposals;

    function _createProposal(uint _startTime, uint _endTime, string calldata _cid)
        internal
        returns (uint)
    {
        uint newPropID = proposals.length;
        proposals.push();

        Proposal storage newProposal = proposals[newPropID];
        newProposal.startTime = _startTime;
        newProposal.endTime = _endTime;
        newProposal.cid = _cid;
        // the remaining vars can start at their zero state
        // i.e. yeaCount and nayCount = 0

        return newPropID;
    }

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

    function _getWeightForMember(address member)
        internal
        view
        returns (uint)
    {
        return 1; // todo
    }

    function vote(uint proposalID, bool isSupporting)
        external
        onlyMember
    {
        Proposal storage proposal = proposals[proposalID];
        require(block.timestamp >= proposal.startTime, "Proposal voting has not yet started.");
        require(block.timestamp < proposal.endTime, "Proposal voting has ended.");
        require(!hasVoted[proposalID][msg.sender], "You already voted on this proposal.");

        uint voteWeight = _getWeightForMember(msg.sender);
        
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

    function getProposal(uint identifier)
        external
        view
        returns (Proposal memory)
    {
        return proposals[identifier];
    }

    function proposalIsActive(Proposal storage proposal)
        internal
        view
        returns (bool)
    {
        return (block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime);
    }

    function getActiveProposalIDs()
        view
        external
        returns (uint[] memory)
    {
        // initialize an array to hold found active props;
        // start it at size proposals.length and trim down later,
        // given that memroy array resizes/pushes are not possible
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

        uint[] memory activeProposalIDsTrimmed = new uint[](numActivePropsFound);
        for (uint i=0; i<numActivePropsFound; i++)
        {
            activeProposalIDsTrimmed[i] = activeProposalIDs[i];
        }

        return activeProposalIDsTrimmed;
    }
}