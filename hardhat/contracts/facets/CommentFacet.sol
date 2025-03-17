// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";

contract CommentFacet {
    AppStorage internal s;

    // Event declarations
    event CommentCreated(
        uint256 indexed commentId,
        address indexed author,
        uint256 indexed entryId,
        string content,
        bool isVoteComment
    );
    event CommentEdited(
        uint256 indexed commentId,
        address indexed author,
        string newContent
    );
    event CommentDeleted(uint256 indexed commentId, address indexed author);
    event CommentReplied(
        uint256 indexed parentCommentId,
        uint256 indexed replyCommentId,
        address indexed author
    );
    event CommentUpvoted(uint256 indexed commentId, address indexed voter);
    event CommentDownvoted(uint256 indexed commentId, address indexed voter);
    event CommentUnvoted(
        uint256 indexed commentId,
        address indexed voter,
        string indexed previousVoteType
    );

    // Helper function to remove an element from an array of CommentVote
    function _removeFromCommentVoteArray(
        CommentVote[] storage array,
        uint256 index
    ) private {
        if (index < array.length - 1) {
            array[index] = array[array.length - 1];
        }
        array.pop();
    }

    // Function to create a comment (either general or vote-comment or reply)
    function createComment(
        uint256 entryId,
        string memory content,
        uint256 parentId, // 0 if no parent comment (for root comments)
        bool isVoteComment, // true for vote-comment, false for regular comment
        uint256 voteId // Required only for vote-comments, can be 0 for regular comments
    ) external {
        // Check if the entry exists
        require(s.entries[entryId].id != 0, "Entry does not exist");

        // For Vote-Comments, ensure the vote exists
        if (isVoteComment) {
            require(s.votes[voteId].voter != address(0), "Vote does not exist");
        }

        // Check if the parent comment exists
        if (parentId != 0) {
            require(
                s.comments[parentId].id != 0,
                "Parent comment does not exist"
            );
            require(
                s.comments[parentId].entryId == entryId,
                "Parent comment is not for this entry"
            );
        }

        // Check if content is not empty
        require(bytes(content).length > 0, "Content cannot be empty");

        uint256 commentId = s.nextCommentId;
        s.nextCommentId++;

        Comment storage comment = s.comments[commentId];

        comment.id = commentId;
        comment.isVoteComment = isVoteComment;
        comment.author = msg.sender;
        comment.content = content;
        comment.timestamp = block.timestamp;
        comment.parentId = parentId;
        comment.entryId = parentId != 0
            ? s.comments[parentId].entryId
            : entryId;
        comment.voteId = voteId;
        comment.replies = new uint256[](0);
        comment.upvotes = new CommentVote[](0);
        comment.downvotes = new CommentVote[](0);
        comment.upvoteCount = 0;
        comment.downvoteCount = 0;

        // Add the comment to the correct storage (either vote-comments or general comments)
        if (isVoteComment) {
            s.commentIndexInVote[commentId] = s.commentsByVotes[voteId].length;
            s.commentsByVotes[voteId].push(commentId);
        } else {
            s.commentIndexInEntry[commentId] = s
                .commentsByEntries[entryId]
                .length;
            s.commentsByEntries[entryId].push(commentId);
        }

        // Add the comment to the list of replies if it's a reply
        if (parentId != 0) {
            s.commentIndexInReplies[commentId] = s
                .repliesByComments[parentId]
                .length;
            s.repliesByComments[parentId].push(commentId);

            // Add the reply to the parent comment's replies
            s.comments[parentId].replies.push(commentId);
        }

        // Add the comment to the user's list of commented entries
        s.userCommentIndex[msg.sender][commentId] = s
            .users[msg.sender]
            .commentedEntries
            .length;
        s.users[msg.sender].commentedEntries.push(comment.entryId);

        emit CommentCreated(
            commentId,
            msg.sender,
            comment.entryId,
            content,
            isVoteComment
        );
    }

    // Function to edit a comment
    function editComment(uint256 commentId, string memory newContent) external {
        // Check if the comment exists
        require(s.comments[commentId].id != 0, "Comment does not exist");

        Comment storage comment = s.comments[commentId];

        // Check if the comment author is the sender
        require(
            comment.author == msg.sender,
            "Only the author can edit the comment"
        );

        // Check if the comment is not deleted
        require(!comment.deleted, "Deleted comments cannot be edited");

        // Check if content is not empty
        require(bytes(newContent).length > 0, "Content cannot be empty");

        comment.content = newContent;
        comment.editedAt = block.timestamp; // Update the edited timestamp

        emit CommentEdited(commentId, msg.sender, newContent);
    }

    // Function to delete a comment
    function deleteComment(uint256 commentId) external {
        // Check if the comment exists
        require(s.comments[commentId].id != 0, "Comment does not exist");

        Comment storage comment = s.comments[commentId];

        // Check if the caller is the author of the comment
        require(
            comment.author == msg.sender,
            "Only the author can delete the comment"
        );

        // Check if the comment is not already deleted
        require(!comment.deleted, "Comment is already deleted");

        // vote-comments cannot be deleted
        require(!comment.isVoteComment, "Vote comments cannot be deleted");

        // Delete the comment content
        comment.content = "";

        // Mark the comment as deleted
        comment.deleted = true;
        comment.deletedAt = block.timestamp;

        emit CommentDeleted(commentId, msg.sender);
    }

    // Function to upvote a comment
    function upvoteComment(uint256 commentId) external {
        // Check if the comment exists
        require(s.comments[commentId].id != 0, "Comment does not exist");

        Comment storage comment = s.comments[commentId];

        // Check if the user has already upvoted or downvoted
        require(
            comment.addressToUpvotes[msg.sender].timestamp == 0,
            "Already upvoted this comment"
        );

        // Check if the comment is not deleted
        require(!comment.deleted, "Deleted comments cannot be downvoted");

        // Remove existing downvote if any
        if (comment.addressToDownvotes[msg.sender].timestamp != 0) {
            comment.downvoteCount--;

            // Remove the downvote from the downvotes array
            uint256 downvoteIndex = s.downvoteIndex[commentId][msg.sender];
            // Check if the comment is not deleted
            _removeFromCommentVoteArray(comment.downvotes, downvoteIndex);
            // Increase the comment author's reputation (undo the downvote reputation decrease)
            s.users[comment.author].reputationScore++;

            delete comment.addressToDownvotes[msg.sender];
        }

        // Add the upvote
        s.upvoteIndex[commentId][msg.sender] = comment.upvotes.length;

        comment.upvotes.push(
            CommentVote({
                voter: msg.sender,
                isUpvote: true,
                timestamp: block.timestamp
            })
        );
        comment.upvoteCount++;

        // Record upvote
        comment.addressToUpvotes[msg.sender] = CommentVote({
            voter: msg.sender,
            isUpvote: true,
            timestamp: block.timestamp
        });

        // Increase the comment author's reputation
        s.users[comment.author].reputationScore++;

        // Record that the user has voted on this comment
        if (!s.users[msg.sender].hasVotedComment[commentId]) {
            s.users[msg.sender].hasVotedComment[commentId] = true;
            s.votedOnCommentIndex[msg.sender][commentId] = s
                .users[msg.sender]
                .votedOnComments
                .length;
            s.users[msg.sender].votedOnComments.push(commentId);
        }
        emit CommentUpvoted(commentId, msg.sender);
    }

    // Function to downvote a comment
    function downvoteComment(uint256 commentId) external {
        // Check if the comment exists
        require(s.comments[commentId].id != 0, "Comment does not exist");

        Comment storage comment = s.comments[commentId];

        // Check if the user has already upvoted or downvoted
        require(
            comment.addressToDownvotes[msg.sender].timestamp == 0,
            "Already downvoted this comment"
        );

        // Check if the comment is not deleted
        require(!comment.deleted, "Deleted comments cannot be downvoted");

        // Remove existing upvote if any
        if (comment.addressToUpvotes[msg.sender].timestamp != 0) {
            comment.upvoteCount--;

            // Remove the upvote from the upvotes array
            uint256 upvoteIndex = s.upvoteIndex[commentId][msg.sender];
            _removeFromCommentVoteArray(comment.upvotes, upvoteIndex);

            // Decrease the comment author's reputation (undo the upvote reputation increase)
            s.users[comment.author].reputationScore--;

            delete comment.addressToUpvotes[msg.sender];
        }

        // Add the downvote
        s.downvoteIndex[commentId][msg.sender] = comment.downvotes.length;
        comment.downvotes.push(
            CommentVote({
                voter: msg.sender,
                isUpvote: false,
                timestamp: block.timestamp
            })
        );
        comment.downvoteCount++;

        // Record downvote
        comment.addressToDownvotes[msg.sender] = CommentVote({
            voter: msg.sender,
            isUpvote: false,
            timestamp: block.timestamp
        });

        // Decrease the comment author's reputation
        s.users[comment.author].reputationScore--;

        // Record that the user has voted on this comment
        if (!s.users[msg.sender].hasVotedComment[commentId]) {
            s.users[msg.sender].hasVotedComment[commentId] = true;
            s.votedOnCommentIndex[msg.sender][commentId] = s
                .users[msg.sender]
                .votedOnComments
                .length;
            s.users[msg.sender].votedOnComments.push(commentId);
        }

        emit CommentDownvoted(commentId, msg.sender);
    }

    // Function to unvote a comment
    function unvoteComment(uint256 commentId) external {
        // Check if the comment exists
        require(s.comments[commentId].id != 0, "Comment does not exist");

        Comment storage comment = s.comments[commentId];

        // Check if the user has upvoted or downvoted the comment
        bool hasUpvoted = comment.addressToUpvotes[msg.sender].timestamp != 0;
        bool hasDownvoted = comment.addressToDownvotes[msg.sender].timestamp !=
            0;
        require(
            hasUpvoted || hasDownvoted,
            "User has not voted on this comment, unable to unvote"
        );

        // Remove the upvote if it exists
        if (hasUpvoted) {
            // Decrement the upvote count
            comment.upvoteCount--;

            // Remove the upvote from the upvotes array
            uint256 upvoteIndex = s.upvoteIndex[commentId][msg.sender];
            _removeFromCommentVoteArray(comment.upvotes, upvoteIndex);

            // Remove the upvote from the addressToUpvotes mapping
            delete comment.addressToUpvotes[msg.sender];

            // Decrease the comment author's reputation score
            s.users[comment.author].reputationScore--;
        }

        // Remove the downvote if it exists
        if (hasDownvoted) {
            // Decrement the downvote count
            comment.downvoteCount--;

            // Remove the downvote from the downvotes array
            uint256 downvoteIndex = s.downvoteIndex[commentId][msg.sender];
            _removeFromCommentVoteArray(comment.downvotes, downvoteIndex);

            // Remove the downvote from the addressToDownvotes mapping
            delete comment.addressToDownvotes[msg.sender];

            // Increase the comment author's reputation (undo the downvote reputation decrease)
            s.users[comment.author].reputationScore++;
        }

        // Remove the comment from the user's votedOnComments list
        uint256[] storage userVotedComments = s
            .users[msg.sender]
            .votedOnComments;
        uint256 index = s.votedOnCommentIndex[msg.sender][commentId];
        if (index < userVotedComments.length - 1) {
            userVotedComments[index] = userVotedComments[
                userVotedComments.length - 1
            ];
            s.votedOnCommentIndex[msg.sender][userVotedComments[index]] = index;
        }
        userVotedComments.pop();

        // Mark the user as not having voted on this comment
        delete s.users[msg.sender].hasVotedComment[commentId];
        delete s.votedOnCommentIndex[msg.sender][commentId];

        emit CommentUnvoted(
            commentId,
            msg.sender,
            hasUpvoted ? "upvote" : "downvote"
        );
    }

    // // Get a comment by ID
    // function getComment(
    //     uint256 commentId
    // ) external view returns (Comment memory) {

    //     require(s.comments[commentId].id != 0, "Comment does not exist");
    //     return s.comments[commentId];
    // }

    // Get all general comments for a listing
    // function getCommentsByEntry(
    //     uint256 entryId
    // ) external view returns (uint256[] memory) {
    //     return s.commentsByEntries[entryId];
    // }

    // // Get all Vote-Comments for a vote
    // function getCommentsByVote(
    //     uint256 voteId
    // ) external view returns (uint256[] memory) {
    //     return s.commentsByVotes[voteId];
    // }

    // // Get all replies to a comment
    // function getRepliesByComment(
    //     uint256 commentId
    // ) external view returns (uint256[] memory) {
    //     return s.repliesByComments[commentId];
    // }
}
