// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// learned from: https://github.com/aavegotchi/aavegotchi-contracts/blob/master/contracts/Aavegotchi/libraries/LibAppStorage.sol
// learned from: eip 2535 app storage reff implementation

// CONSTANTS
uint256 constant MIN_ATTESTATIONS_FOR_MINT = 2;
// constants can be used in appstorage and structs outside app storage

// (do not create structs directly in appstorage)

// USER STATES
// The User struct which stores the details of each user
struct User {
    uint256 id; // The ID of the User
    string name; // Name of the user
    address walletAddress; // Wallet address of the user
    uint256 registeredAt; // Timestamp of user registration
    int256 reputationScore; // Reputation score of the user
    bool isBanned; // Flag indicating if the user is banned
    uint256[] createdEntries; // List of Entry IDs created by the user
    uint256[] votedEntries; // List of Entry IDs the user has voted on. (contains voteDetails(vote+comment))
    uint256[] commentedEntries; // List of Entry IDs the user has commented on
    uint256[] votedOnComments; // List of Comment IDs where the user has voted on comments
    mapping(uint256 => bool) hasVotedComment; // Track whether the user has voted on a specific Comment
    mapping(uint256 => bool) hasVotedEntry; // Track whether the user has voted on a specific Entry
    mapping(uint256 => VoteDetail) entryVotes; // Track votes per entry (entryId => VoteDetail)
}
// USER STATES END

// ENTRY STATES
// Enum for Entry states
enum EntryState {
    Active,
    Archived,
    Minted
}

// Enum for Vote Types
enum VoteType {
    Attest,
    Refute
}

// Struct to store vote details along with the comment
struct VoteDetail {
    uint256 voteId; // ID of the vote
    address voter; // Voter address
    VoteType voteType; // Type of the vote (Attest or Refute)
    uint256 voteCommentId; // ID linking to a VoteComment for this vote
    uint256 voteIndex; // Index in votes array for efficient removal
    uint256 votedAt; // Timestamp of vote
}

// Struct to store entry updates
struct UpdateNote {
    uint256 id; // Unique ID for the update-note
    uint256 entryId; // The ID of the entry this update-note belongs to
    string content; // The content of the update-note
    uint256 timestamp; // Timestamp when the update-note was created
}

// The Entry struct which stores the details of each Entry
struct Entry {
    uint256 id; // The ID of the Entry
    address creator; // The creator of the Entry
    string title; // Title of the Entry
    string details; // Details of the Entry
    string[] proofs; // Proofs related to the Entry
    string category; // Category of the Entry
    uint256 createdAt; // Timestamp of Entry creation
    uint256 editedAt; // Timestamp of Entry last edit
    uint256 archivedAt; // Timestamp of Entry archival
    EntryState state; // Current state of the Entry (Active, Archived, Minted)
    VoteDetail[] votes; // List of votes for the Entry
    mapping(address => VoteDetail) addressToVotes; // Map voter address to their vote
    uint256 totalAttestCount; // Total number of attest votes for the Entry
    uint256 totalRefuteCount; // Total number of refute votes for the Entry
    uint256 linkedToPreviousId; // Linked to a previous Entry if this Entry is created upon an archived Entry
    uint256 linkedToNewId; // Linked to a new Entry if this Entry is archived and a new Entry is created upon it
    uint256[] previousEntries; // Array to track all previous linked entries ("version history")
    string archiveNote; // Archive note when applicable
    uint256 tokenId; // Token ID of the minted NFT (0 if not minted)
}
// ENTRY STATES END

// COMMENT STATES

// A struct to store vote details for each comment
struct CommentVote {
    address voter; // The address of the voter
    bool isUpvote; // True if upvote, false if downvote
    uint256 timestamp; // Timestamp when the vote was cast
}

// Unified Comment struct for both Vote-Comments and General Comments
struct Comment {
    uint256 id; // Unique ID of the comment
    bool isVoteComment; // Flag to indicate if it's a vote-comment or a general comment
    address author; // Author of the comment
    string content; // Content of the comment
    uint256 timestamp; // Timestamp when the comment was created
    uint256 editedAt; // Timestamp when the comment was last edited
    uint256 parentId; // Parent comment ID (0 if it's a root comment)
    uint256 entryId; // The associated Entry ID (for general comments)
    uint256 voteId; // The associated Vote ID (for vote-comments)
    uint256[] replies; // List of Comment IDs for replies (nested comments)
    // Mappings for upvotes and downvotes
    mapping(address => CommentVote) addressToUpvotes; // Mapping to store upvotes (address => vote details)
    mapping(address => CommentVote) addressToDownvotes; // Mapping to store downvotes (address => vote details)
    // list of all upvotes and downvotes
    CommentVote[] upvotes;
    CommentVote[] downvotes;
    uint256 upvoteCount; // Total upvote count for the comment
    uint256 downvoteCount; // Total downvote count for the comment
    bool deleted; // Flag to indicate if the comment is deleted
    uint256 deletedAt; // Timestamp when the comment was deleted
}

// COMMENT STATES END

// The storage struct holds all necessary state variables for facets
struct AppStorage {
    // USER STORAGE
    uint256 nextUserId; // Counter for generating unique User IDs
    mapping(address => User) users; // User Address => User struct
    // USER STORAGE END

    // ENTRY STORAGE
    uint256 nextEntryId; // Counter for generating unique Entry IDs
    mapping(uint256 => Entry) entries; // Stores Entries by ID
    mapping(bytes32 => bool) entryHashes; // Prevents duplicate Entries from same user
    // UPDATE-NOTE STORAGE
    uint256 nextUpdateNoteId; // Counter for generating unique UpdateNote IDs
    mapping(uint256 => UpdateNote) updateNotes; // UpdateNote ID => UpdateNote data
    mapping(uint256 => uint256[]) updateNotesByEntry; // Entry ID => List of UpdateNote IDs
    // ENTRY STORAGE END

    // COMMENT STORAGE
    uint256 nextCommentId; // Counter for generating unique Comment IDs
    mapping(uint256 => Comment) comments; // Comment ID => Comment data
    mapping(uint256 => uint256[]) commentsByEntries; // Entry ID => List of Comment IDs (general comments)
    mapping(uint256 => uint256[]) commentsByVotes; // Vote ID => List of Comment IDs (vote-comments)
    mapping(uint256 => uint256[]) repliesByComments; // Comment ID (parent comment) => List of Comment IDs (replies to comments)
    // Mapping to track the index of comments in their respective arrays
    mapping(uint256 => uint256) commentIndexInEntry; // Comment ID => Index in commentsByEntries
    mapping(uint256 => uint256) commentIndexInVote; // Comment ID => Index in commentsByVotes
    mapping(uint256 => uint256) commentIndexInReplies; // Comment ID => Index in repliesByComments
    // Mapping to track the index of votes in their respective arrays
    mapping(uint256 => mapping(address => uint256)) upvoteIndex; // Comment ID => Voter address => Index in upvotes
    mapping(uint256 => mapping(address => uint256)) downvoteIndex; // Comment ID => Voter address => Index in downvotes
    // Mapping to track the index of comments in the user's commentedEntries array
    mapping(address => mapping(uint256 => uint256)) userCommentIndex; // User address => Comment ID => Index in commentedEntries
    // Mapping to track the index of comments in the user's votedOnComments array
    mapping(address => mapping(uint256 => uint256)) votedOnCommentIndex; // User address => Comment ID => Index in votedOnComments
    // COMMENT STORAGE END

    // COMMENT VOTE STORAGE
    uint256 nextVoteId; // Counter for generating unique Vote IDs
    mapping(uint256 => VoteDetail) votes; // Vote ID => VoteDetail
    // COMMENT VOTE STORAGE END

    // NFT STORAGE
    bool initialized; // Flag to track if the contract has been initialized
    uint256 nextTokenId; // Counter for generating unique token IDs
    string tokenName; // Token name
    string tokenSymbol; // Token symbol
    bool paused; // Pause state for the NFT contract
    mapping(uint256 => address) owners; // Token ID => Owner
    mapping(address => uint256) balances; // Owner => Balance
    mapping(uint256 => string) tokenURIs; // Token ID => URI
    mapping(uint256 => uint256) tokenToEntryId; // Token ID => Entry ID


    // NFT STORAGE END

    // REPUTATION STORAGE
    // s.users[msg.sender].reputationScore handles the reputation score of the user so no need to store it here
    // mapping(address => uint256) userReputation; // User address => Reputation score
    // REPUTATION STORAGE END
}

library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }

    function someFunction() internal {
        AppStorage storage s = appStorage();
        // s.firstVar = 8;
        //... do more stuff
    }
}

// // Helper function to generate the hash for entries
// function generateEntryHash(string memory title, string memory details, string memory category) internal pure returns (bytes32) {
//     return keccak256(abi.encodePacked(title, details, category));
// }

// --- Modifiers ---

contract Modifiers {
    AppStorage internal s;

    modifier entryExists(uint256 entryId) {
        require(entryId < s.nextEntryId, "Invalid entry ID");
        _;
    }

    modifier onlyCreator(uint256 entryId) {
        require(
            msg.sender == s.entries[entryId].creator,
            "Unauthorized: Not entry creator"
        );
        _;
    }

    modifier onlyActive(uint256 entryId) {
        require(
            s.entries[entryId].state == EntryState.Active,
            "Invalid entry State: Not Active"
        );
        _;
    }

    //     modifier canEditentry(uint256 entryId) {
    //         require(
    //             entryId < s.nextEntryId &&
    //                 s.Entries[entryId].state == EntryState.Active &&
    //                 !hasVotes(entryId),
    //             "Cannot edit entry: Invalid state or has votes"
    //         );
    //         _;
    //     }

    //     function hasVotes(uint256 entryId) internal view returns (bool) {
    //         EntryCount memory counts = s.EntryCounts[entryId];
    //         return counts.attestCount > 0 || counts.refuteCount > 0;
    //     }
}
