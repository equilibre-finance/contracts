pragma solidity 0.8.13;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "contracts/BulkSender.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface CheatCodes {
    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);
}

contract BulkSenderTest is Test {

    MockERC20 usdc;
    BulkSender sender;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        sender = new BulkSender();
        usdc = new MockERC20("USDC", "USDC", 6);
        // ---
    }

    function testSendERC20() public {
        uint total = 200;
        address[] memory empty = new address[](0);
        address[] memory addresses = new address[](total);
        for( uint i = 0 ; i < total ; i ++ ){
            addresses[i] = cheats.addr(i+1);
        }

        address[] memory invalidRecipient = new address[](2);
        invalidRecipient[0] = address(0); // skip
        invalidRecipient[1] = address(0);

        uint amount = 1 * 1e6;
        vm.expectRevert(abi.encodePacked(BulkSender.InvalidToken.selector));
        sender.sendSameAmountToMany( IERC20(address(0)), addresses, amount);

        vm.expectRevert(abi.encodePacked(BulkSender.InvalidRecipients.selector));
        sender.sendSameAmountToMany( IERC20(address(usdc)), empty, amount);

        vm.expectRevert(abi.encodePacked(BulkSender.InvalidAmount.selector));
        sender.sendSameAmountToMany( IERC20(address(usdc)), addresses, 0);

        vm.expectRevert(abi.encodePacked(BulkSender.NotEnoughBalance.selector));
        sender.sendSameAmountToMany( IERC20(address(usdc)), addresses, amount);

        uint totalAmount = amount * total;
        usdc.mint(address(this), totalAmount);

        vm.expectRevert(abi.encodePacked(BulkSender.NotEnoughApproval.selector));
        sender.sendSameAmountToMany( IERC20(address(usdc)), addresses, amount);

        usdc.approve(address(sender), totalAmount);

        vm.expectRevert(abi.encodePacked(BulkSender.InvalidRecipient.selector));
        sender.sendSameAmountToMany( IERC20(address(usdc)), invalidRecipient, amount);

        sender.sendSameAmountToMany( IERC20(address(usdc)), addresses, amount);

        assertEq(usdc.balanceOf(addresses[1]), amount);

    }

    function testSendValue() public {
        uint total = 200;
        address[] memory empty = new address[](0);
        address[] memory addresses = new address[](total);
        for( uint i = 0 ; i < total ; i ++ ){
            addresses[i] = cheats.addr(i+1);
        }

        address[] memory invalidRecipient = new address[](2);
        invalidRecipient[0] = address(0); // skip
        invalidRecipient[1] = address(0);

        uint amount = 0.1 ether;
        uint value = amount * total;
        uint lowAmount = 0.1 ether;

        vm.expectRevert(abi.encodePacked(BulkSender.InvalidRecipients.selector));
        sender.sendSameAmountToManyInFee{value: value}(empty, amount);

        vm.expectRevert(abi.encodePacked(BulkSender.InvalidAmount.selector));
        sender.sendSameAmountToManyInFee{value: value}(addresses, 0);

        vm.expectRevert(abi.encodePacked(BulkSender.NotEnoughBalance.selector));
        sender.sendSameAmountToManyInFee{value: lowAmount}(addresses, amount);

        vm.expectRevert(abi.encodePacked(BulkSender.InvalidRecipient.selector));
        sender.sendSameAmountToManyInFee{value: value}(invalidRecipient, amount);

        sender.sendSameAmountToManyInFee{value: value}(addresses, amount);

        assertEq(address(addresses[1]).balance, amount);

    }


    function testSendKavaToMany() public {
        uint total = 200;
        uint amount = 0.1 ether;
        uint value = amount * total;
        uint lowAmount = 0.1 ether;

        address[] memory empty = new address[](0);
        address[] memory emptyValues = new address[](0);

        address[] memory addresses = new address[](total);
        uint[] memory values = new uint[](total);
        for( uint i = 0 ; i < total ; i ++ ){
            addresses[i] = cheats.addr(i+1);
            values[i] = amount;
        }

        address[] memory invalidRecipient = new address[](2);
        uint[] memory invalidValue = new uint[](2);
        invalidRecipient[0] = address(0);
        invalidRecipient[1] = address(0);

        invalidValue[0] = 0;
        invalidValue[1] = 0;

        sender.sendKavaToMany{value: value}(addresses, values);

        for( uint i = 0 ; i < total ; i ++ ){
            assertEq(address(addresses[i]).balance, values[i]);
        }


    }

}
