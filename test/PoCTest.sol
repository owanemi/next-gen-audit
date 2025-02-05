// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/Token.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract EURFTokenTest is Test {
    EURFToken public implementation;
    EURFToken public token;
    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public feesFaucet;
    address public forwarder;

    event FeesPaid(address indexed from, uint256 amount);
    event GaslessBasefeePaid(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        owner = address(this);
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        feesFaucet = makeAddr("feesFaucet");
        forwarder = makeAddr("forwarder");

        // Deploy implementation
        implementation = new EURFToken();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSignature("initialize()");
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // Get token instance pointing to proxy
        token = EURFToken(address(proxy));
    }

    function test_initialization() public {
        assertEq(token.name(), "EURF");
        assertEq(token.symbol(), "EURF");
        assertEq(token.decimals(), 6);
        assertEq(token.owner(), address(this));
    }

    function test_setOwner() public {
        vm.startPrank(user1);
        token.setOwner(user1);
        assertEq(token.owner(), user1);
    }

    function test_setMasterMinter_accessControl() public {
        // Anyone can set master minter
        vm.startPrank(user1);
        token.setMasterMinter(user1);

        // Verify attacker becomes master minter
        assertTrue(token.isMasterMinter(user1));

        // Test minting capability
        token.mint(user1, 1000000 * 10 ** 6);

        assertEq(token.balanceOf(user1), 1000000 * 10 ** 6);
    }

    function testFail_setOwner_zeroAddress() public {
        token.setOwner(address(0));
    }

    function testFail_setOwner_sameOwner() public {
        token.setOwner(owner);
    }

    function test_setTrustedForwarder() public {
        // Grant admin role first
        token.grantRole(token.ADMIN(), admin);

        vm.prank(admin);
        token.setTrustedForwarder(forwarder);
        assertTrue(token.isTrustedForwarder(forwarder));
    }

    function testFail_setTrustedForwarder_nonAdmin() public {
        vm.prank(user1);
        token.setTrustedForwarder(forwarder);
    }

    function test_setFeeFaucet() public {
        // Grant admin role first
        token.grantRole(token.ADMIN(), admin);

        vm.prank(admin);
        token.setFeeFaucet(feesFaucet);
        // We would need a public getter to verify this
    }

    // function test_setTxFeeRate() public {
    //     // Grant admin role first
    //     token.grantRole(token.ADMIN(), admin);

    //     vm.prank(admin);
    //     token.setTxFeeRate(100); // 1%
    // }

    // function test_transfer_withFees() public {
    //     // Setup
    //     token.grantRole(token.ADMIN(), admin);
    //     vm.prank(admin);
    //     token.setTxFeeRate(1000); // 10% fee
    //     token.setFeeFaucet(feesFaucet);

    //     // Mint some tokens to user1
    //     token.grantRole(token.MINTER_ROLE(), address(this));
    //     token.mint(user1, 1000 * 10**6); // 1000 EURF

    //     // Transfer from user1 to user2
    //     vm.prank(user1);
    //     token.transfer(user2, 100 * 10**6); // Transfer 100 EURF

    //     // Check balances
    //     assertEq(token.balanceOf(user2), 100 * 10**6); // User2 should receive 100 EURF
    //     assertEq(token.balanceOf(feesFaucet), 10 * 10**6); // FeesFaucet should receive 10 EURF (10% fee)
    //     assertEq(token.balanceOf(user1), 890 * 10**6); // User1 should have 890 EURF left
    // }

    function testFail_transfer_insufficientBalance() public {
        // Setup fees
        token.grantRole(token.ADMIN(), admin);
        vm.prank(admin);
        token.setTxFeeRate(1000); // 10% fee
        token.setFeeFaucet(feesFaucet);

        // Mint some tokens to user1 (not enough for transfer + fees)
        token.grantRole(token.MINTER_ROLE(), address(this));
        token.mint(user1, 100 * 10 ** 6); // 100 EURF

        // Try to transfer more than available balance including fees
        vm.prank(user1);
        token.transfer(user2, 95 * 10 ** 6); // This should fail as fees would make total > 100 EURF
    }

    // function test_gaslessBasefee() public {
    //     // Setup
    //     token.grantRole(token.ADMIN(), admin);
    //     vm.prank(admin);
    //     token.setTrustedForwarder(forwarder);
    //     token.setGaslessBasefee(1 * 10**6); // 1 EURF base fee

    //     // Mint tokens to user1
    //     token.grantRole(token.MINTER_ROLE(), address(this));
    //     token.mint(user1, 10 * 10**6); // 10 EURF

    //     // Pay gasless basefee
    //     vm.prank(forwarder);
    //     token.payGaslessBasefee(user1, user2);

    //     // Check balances
    //     assertEq(token.balanceOf(user2), 1 * 10**6); // User2 should receive 1 EURF base fee
    //     assertEq(token.balanceOf(user1), 9 * 10**6); // User1 should have 9 EURF left
    // }

    function testFail_gaslessBasefee_unauthorizedForwarder() public {
        vm.prank(user1);
        token.payGaslessBasefee(user1, user2);
    }

    function test_transferWithAuthorization() public {
        // This would require implementing the signing logic
        // Skipping for now as it requires more complex setup
    }

    // Fuzz tests
    function testFuzz_setTxFeeRate(uint256 newRate) public {
        // Grant admin role first
        vm.assume(newRate > 0 && newRate <= 10000); // Reasonable bounds
        token.grantRole(token.ADMIN(), admin);

        vm.prank(admin);
        token.setTxFeeRate(newRate);
        // Add assertions if there's a getter for tx fee rate
    }

    // function testFuzz_transfer(uint256 amount) public {
    //     vm.assume(amount > 0 && amount <= 1000000 * 10**6); // Reasonable bounds

    //     // Mint tokens to user1
    //     token.grantRole(token.MINTER_ROLE(), address(this));
    //     token.mint(user1, amount);

    //     // Transfer from user1 to user2
    //     vm.prank(user1);
    //     token.transfer(user2, amount);

    //     assertEq(token.balanceOf(user2), amount);
    //     assertEq(token.balanceOf(user1), 0);
    // }
}
