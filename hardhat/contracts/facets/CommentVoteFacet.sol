// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";

contract CommentVoteFacet {
    AppStorage internal s;

    // Event declarations
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

    // Function to upvote a comment
    function upvoteComment(uint256 commentId) external {
        // Check if the comment exists
        require(s.comments[commentId].id != 0, "Comment does not exist");

        Comment storage comment = s.comments[commentId];

        // Check if the user has already upvoted
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

        // Check if the user has already downvoted
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
        bool hasDownvoted = comment.addressToDownvotes[msg.sender].timestamp != 0;
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
}