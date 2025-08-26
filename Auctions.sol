// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.30;

contract Auctions {

    event AuctionStarted(uint256 auctionId, address auctioner);
    event BidPlaced(uint256 auctionId, address bidder, uint256 bid);
    event AuctionEnded(uint256 auctionId, address winner);
    event FundsWithdrawn(address by, uint256 amount);

    struct Auction {
        address seller;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool closed;
    }
    Auction[] public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(address => uint256) public pendingWithdrawals;

    function startAuction(uint256 minBid, uint256 duration) external {
        require(duration > 0, "Duration must be greater than 0");
        Auction memory auction;
        auction.seller = msg.sender;
        auction.minBid = minBid;
        auction.endTime = block.timestamp + duration;
        auction.closed = false;

        auctions.push(auction);
        emit AuctionStarted(auctions.length - 1, msg.sender);
    }

    function placeBid(uint256 auctionId) external payable {
        require(auctionId < auctions.length, "Invalid auction id");
        Auction storage auction = auctions[auctionId];
        require(!auction.closed, "This auction is closed");
        require(block.timestamp < auction.endTime, "This auction has ended");
        require(
            msg.value > auction.minBid && msg.value > auction.highestBid,
            "Bid must be higher"
        );
        if(auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder] += auction.highestBid;
        }
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        bids[auctionId][msg.sender] += msg.value;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function closeAuction(uint256 auctionId) external {
        require(auctionId < auctions.length, "Invalid auction ID");
        Auction storage auction = auctions[auctionId];
        require(!auction.closed, "Auction already closed");
        require(
            msg.sender == auction.seller,
            "Not authorized"
        );
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(auction.highestBidder != address(0), "No bids placed");

        auction.closed = true;
        pendingWithdrawals[auction.seller] += auction.highestBid;

        emit AuctionEnded(auctionId, auction.highestBidder);
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(msg.sender, amount);
    }

    function getAuctionCount() external view returns (uint256) {
        return auctions.length;
    }
}
