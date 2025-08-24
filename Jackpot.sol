// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Jackpot is Ownable, Pausable, ReentrancyGuard {
    event BetPlaced(address player, uint256 value);
    event GameResolved(address winner, uint256 prize);

    struct Game {
        uint256 total;
        address[] players;
        mapping(address => uint256) bets;
        bool joinable;
    }

    Game private game;

    constructor() Ownable(msg.sender) {
        game.joinable = true;
    }

    function getPseudoRandomNumber(uint256 max) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender
                    )
                )
            ) % max;
    }

    function placeBet() external payable whenNotPaused nonReentrant {
        require(game.joinable == true, "");
        require(msg.value > 0, "Bet must be > 0");
        if (game.bets[msg.sender] == 0) {
            game.players.push(msg.sender);
        }
        game.bets[msg.sender] += msg.value;
        game.total += msg.value;
        emit BetPlaced(msg.sender, msg.value);
    }

    function resolveGame()
        external
        payable
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        require(game.joinable, "Game is not joinable");
        require(game.total > 0, "No bets placed");
        game.joinable = false;
        uint256 rand = getPseudoRandomNumber(game.total);
        uint256 cumulative = 0;
        address winner;
        for (uint256 i = 0; i < game.players.length; i++) {
            cumulative += game.bets[game.players[i]];
            if (rand < cumulative) {
                winner = game.players[i];
                break;
            }
        }
        uint256 prize = game.total;
        game.total = 0;
        (bool sent, ) = payable(winner).call{value: prize}("");
        require(sent, "Failed to send prize");
        emit GameResolved(winner, prize);
        for (uint256 i = 0; i < game.players.length; i++) {
            delete game.bets[game.players[i]];
        }
        delete game.players;
        game.joinable = true;
    }

    function getTotalPot() external view returns (uint256) {
        return game.total;
    }

    function getPlayerBet(address player) external view returns (uint256) {
        return game.bets[player];
    }

    function isGameJoinable() external view returns (bool) {
        return game.joinable;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
