// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <=0.9.0;

contract Vote {
    address public electionCommission;
    bool public stopVoting;

    // Separate counters for candidate and voter IDs per constituency (vidhansabha)
    mapping(JharkhandElection => uint) private nextVoterId;
    mapping(JharkhandElection => uint) private nextCandidateId;

    event CandidateRegistered(uint candidateId, string name);
    event VoterRegistered(uint voterId, string name);
    event VoteCast(address voter, uint candidateId);
    event Winner(uint candidateId, string name, Party party, uint votes, address candidateAddress);

    modifier onlyCommissioner() {
        require(msg.sender == electionCommission, "Not authorized");
        _;
    }

    modifier isValidAge(uint _age) {
        require(_age >= 18, "Not eligible for voting");
        _;
    }

    enum Gender { Male, Female, Other }
    enum JharkhandElection { Bermo, Dumri, Gomia, Tundi, Dhanbad }
    enum Party { None, JLKM, JMM, CONGRESS, AJSU, BJP }

    struct Candidate {
        string candidateImage;
        string name;
        uint age;
        Gender gender;
        uint candidateId;
        JharkhandElection vidhansabha;
        Party party;
        address candidateAddress;
        uint votes;
    }

    struct Voter {
        string voterImage;
        string name;
        uint age;
        Gender gender;
        uint voterId;
        JharkhandElection vidhansabha;
        Party party;
        address voterAddress;
        uint voteCandidateId; // 0 means no vote
        bool hasVoted; // Track if the voter has voted
    }

    mapping(JharkhandElection => mapping(uint => Candidate)) public candidateList;
    mapping(JharkhandElection => mapping(uint => Voter)) public voterList;
    mapping(address => bool) public isVoterRegistered;

    constructor(address _electionCommission) {
        electionCommission = _electionCommission;
    }

    // Helper function to check if the candidate is already registered in the given vidhansabha
    function isCandidateNotRegistered(address _person, JharkhandElection _vidhansabha) private view returns (bool) {
        for (uint i = 1; i <= nextCandidateId[_vidhansabha]; i++) {
            if (candidateList[_vidhansabha][i].candidateAddress == _person) {
                return false;
            }
        }
        return true;
    }

    // Check if the party already has a candidate registered in the given constituency
    function isPartyNotRegisted(JharkhandElection _vidhanSabha, Party _party) private view returns (bool) {
        for (uint i = 1; i <= nextCandidateId[_vidhanSabha]; i++) {
            Party registeredParty = candidateList[_vidhanSabha][i].party;
            if (registeredParty == _party) {
                return false;
            }
            if (_party == Party.AJSU || _party == Party.BJP) {
                if (registeredParty == Party.AJSU || registeredParty == Party.BJP) {
                    return false;
                }
            }

            if (_party == Party.JMM || _party == Party.CONGRESS) {
                if (registeredParty == Party.JMM || registeredParty == Party.CONGRESS) {
                    return false;
                }
            }
        }
        return true;
    }

    // Register a new candidate
    function registerCandidate(
        string calldata _candidateImage,
        string calldata _name,
        uint _age,
        Gender _gender,
        JharkhandElection _vidhanSabha,
        Party _party,
        address _candidateAddress
    ) external onlyCommissioner isValidAge(_age) {
        require(nextCandidateId[_vidhanSabha] < 4, "Candidate limit reached for this constituency");
        require(isCandidateNotRegistered(_candidateAddress, _vidhanSabha), "Candidate already registered");
        require(isPartyNotRegisted(_vidhanSabha, _party), "Party already has a candidate in this constituency or party alliance restrictions apply");

        uint newCandidateId = nextCandidateId[_vidhanSabha] + 1; // Always start from 1 for each constituency
        candidateList[_vidhanSabha][newCandidateId] = Candidate({
            candidateImage: _candidateImage,
            name: _name,
            age: _age,
            gender: _gender,
            candidateId: newCandidateId,
            vidhansabha: _vidhanSabha,
            party: _party,
            candidateAddress: _candidateAddress,
            votes: 0
        });

        emit CandidateRegistered(newCandidateId, _name);

        // Increment the candidate ID counter for the next candidate in this constituency
        nextCandidateId[_vidhanSabha] = newCandidateId;
    }

    // Register a new voter
    function registerVoter(
        string calldata _voterImage,
        string calldata _name,
        uint _age,
        Gender _gender,
        JharkhandElection _vidhansabha
    ) public isValidAge(_age) {
        require(!isVoterRegistered[msg.sender], "Voter already registered");

        uint newVoterId = nextVoterId[_vidhansabha] + 1; // Always start from 1 for each constituency
        voterList[_vidhansabha][newVoterId] = Voter({
            voterImage: _voterImage,
            name: _name,
            age: _age,
            gender: _gender,
            voterId: newVoterId,
            vidhansabha: _vidhansabha,
            party: Party.None,
            voterAddress: msg.sender,
            voteCandidateId: 0,
            hasVoted: false
        });

        isVoterRegistered[msg.sender] = true;
        emit VoterRegistered(newVoterId, _name);

        // Increment the voter ID counter for the next voter in this constituency
        nextVoterId[_vidhansabha] = newVoterId;
    }

    // Cast a vote for a candidate
    function castVote(JharkhandElection _vidhansabha, uint _voterId, uint _candidateId) external {
        require(voterList[_vidhansabha][_voterId].voteCandidateId == 0, "You have already voted");
        require(voterList[_vidhansabha][_voterId].voterAddress == msg.sender, "Voter not registered");
        require(_candidateId >= 1 && _candidateId <= nextCandidateId[_vidhansabha], "Invalid candidate ID");
        require(voterList[_vidhansabha][_voterId].vidhansabha == candidateList[_vidhansabha][_candidateId].vidhansabha, "Voting in wrong constituency");
        voterList[_vidhansabha][_voterId].voteCandidateId = _candidateId;
        candidateList[_vidhansabha][_candidateId].votes++;
        voterList[_vidhansabha][_voterId].hasVoted = true;

        emit VoteCast(msg.sender, _candidateId);
    }
    function announceVotingResult(JharkhandElection _vidhansabha) external onlyCommissioner {
        uint maxVotes = 0;
        uint candidateId;
        string memory winnerCandidate;
        address winnerAddress;
        Party _party;
        for (uint i = 1; i <= nextCandidateId[_vidhansabha]; i++) {
            if (candidateList[_vidhansabha][i].votes > maxVotes) {
                candidateId = candidateList[_vidhansabha][i].candidateId;
                winnerCandidate = candidateList[_vidhansabha][i].name;
                _party = candidateList[_vidhansabha][i].party;
                maxVotes = candidateList[_vidhansabha][i].votes;
                winnerAddress = candidateList[_vidhansabha][i].candidateAddress;
            }
        }
        emit Winner(candidateId, winnerCandidate, _party, maxVotes, winnerAddress);
    }
}
