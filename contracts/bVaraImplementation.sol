// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {OFTUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/oft/OFTUpgradeable.sol";
import {ILayerZeroEndpointUpgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/interfaces/ILayerZeroEndpointUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20} from '../lib/solmate/src/tokens/ERC20.sol';
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

//import {console2} from "forge-std/console2.sol";

contract bVaraImplementation is Initializable, OFTUpgradeable
{

    uint public minWithdrawDays;
    uint public maxPenaltyPct;

    ERC20 public asset;
    IVotingEscrow public ve;

    /// @dev controls who can do transfers:
    mapping(address => bool) public whiteList;

    /// @dev last mint timestamp for each user for penalty calculation:
    mapping(address => uint) public lastMint;

    event WhiteList(address indexed _addr, bool _status);
    event Redeemed(address indexed _addr, uint256 _amount, uint256 _redeemAmount);

    error NonWhiteListed();
    error InsufficientBalance();
    error InsufficientAllowance();

    function initialize( ERC20 _asset, address _ve ) initializer public {

        __OFTUpgradeable_init("bVara Token", "bVARA", address(0));

        asset = _asset;
        ve = IVotingEscrow(_ve);

        /// @dev set default values for proxy:
        minWithdrawDays = 90 days;
        maxPenaltyPct = 90;

        /// @dev set owner as whiteListed:
        whiteList[_msgSender()] = true;
        emit WhiteList(_msgSender(), true);

        /// @dev whitelist 0 address as it is the minter:
        whiteList[address(0)] = true;
        emit WhiteList(address(0), true);

    }

    // @dev determine the penalty for withdrawing before the withdrawal window:
    function penalty(uint256 secs) public view returns (uint256 pct) {

        /// @dev max penalty if <= than 1 day:
        if (secs <= 1 days) return maxPenaltyPct;

        /// @dev no penalty if >= than minWithdrawDays:
        if (secs >= minWithdrawDays) return 0;

        /// @dev calculate penalty % on time decay:
        pct = maxPenaltyPct - (maxPenaltyPct * secs / minWithdrawDays);

    }

    // @dev sets the LZ endpoint anytime if we need it:
    function setEndpoint(address _endpoint) public onlyOwner {
        lzEndpoint = ILayerZeroEndpointUpgradeable(_endpoint);
    }

    /// @dev set mint withdrawal window in days to avoid penalties:
    function setWithdrawalWindow(uint256 _withdrawalWindow) public onlyOwner {
        minWithdrawDays = _withdrawalWindow;
    }

    /// @dev set whiteList status for _addr, allowing it to transfer bToken:
    function setWhitelist(address _addr, bool _status) public onlyOwner {
        whiteList[_addr] = _status;
        emit WhiteList(_addr, _status);
    }

    /// @dev mint bToken to _to, transfer _amount of asset from msg sender to this contract:
    function mint(address _to, uint256 _amount) public onlyOwner {

        /// @dev check allowance:
        if (asset.allowance(_msgSender(), address(this)) < _amount) {
            revert InsufficientAllowance();
        }

        /// @dev check balance:
        if (asset.balanceOf(_msgSender()) < _amount) {
            revert InsufficientBalance();
        }

        /// @dev transfer asset to this contract:
        SafeTransferLib.safeTransferFrom(asset, _msgSender(), address(this), _amount);

        /// @dev mint bToken to _to:
        _mint(_to, _amount);

        /// @dev update last mint timestamp for penalty calculation:
        lastMint[_to] = block.timestamp;

    }

    /// @dev admin can burn tokens and transfer asset to _to:
    function burn(address _from, uint256 _amount) public onlyOwner {

        /// @dev burn bToken:
        _burn(_from, _amount);

        /// @dev transfer asset to _to:
        SafeTransferLib.safeTransfer(asset, _from, _amount);

    }

    /// @dev compute penalty amount for _amount of bToken:
    function computePenaltyRedemption(address user, uint256 _amount) public view returns (uint256 _penaltyAmount) {
        uint256 secs = block.timestamp - lastMint[user];
        uint256 _penalty = penalty(secs);
        _penaltyAmount = _amount - (_amount * _penalty / 100);
    }

    /// @dev redeem bToken for asset with penalty check:
    function redeem(uint256 _amount) public {

        /// @dev check penalty:
        uint256 _redeemAmount = computePenaltyRedemption(_msgSender(), _amount);

        /// @dev burn bToken:
        _burn(_msgSender(), _amount);

        /// @dev transfer asset to msg sender:
        SafeTransferLib.safeTransfer(asset, _msgSender(), _redeemAmount);

        emit Redeemed(_msgSender(), _amount, _redeemAmount);
    }

    /// @dev convert bVARA to veVARA:
    function convertToVe(uint256 _amount) public returns (uint256 tokenId){

        /// @dev check balance:
        if (balanceOf(_msgSender()) < _amount) {
            revert InsufficientBalance();
        }

        /// @dev burn bToken:
        _burn(_msgSender(), _amount);

        /// @dev mint veToken:
        asset.approve(address(ve), _amount);

        /// @dev conversion always lock for 4y:
        uint _lock_duration = ( (block.timestamp + (365 days * 4) ) / 1 weeks * 1 weeks) - 1;
        return ve.create_lock_for(_amount, _lock_duration, _msgSender());

    }

    /// @dev only allow transfers if from or to is whiteListed:
    function _beforeTokenTransfer(address from, address to, uint256) internal override view {
        /// @dev check if from or to is whiteListed:
        if (!whiteList[from] && !whiteList[to]) {
            revert NonWhiteListed();
        }
    }

}
