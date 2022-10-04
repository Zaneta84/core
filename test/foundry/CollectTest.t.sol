// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import './base/BaseTest.t.sol';

contract CollectTest is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(profileOwner);
        hub.post(mockPostData);
    }

    // negatives
    function testCollectNonexistantPublicationFails() public {
        vm.expectRevert(Errors.PublicationDoesNotExist.selector);
        hub.collect(me, firstProfileId, 2, '');
    }

    function testCollectZeroPublicationFails() public {
        vm.expectRevert(Errors.PublicationDoesNotExist.selector);
        hub.collect(me, 0, 0, '');
    }

    function testCollectNotExecutorFails() public {
        vm.prank(otherSigner);
        vm.expectRevert(Errors.ExecutorInvalid.selector);
        hub.collect(me, firstProfileId, 1, '');
    }

    // positives
    function testCollect() public {
        assertEq(hub.getCollectNFT(firstProfileId, 1), address(0));

        uint256 nftId = hub.collect(me, firstProfileId, 1, '');
        CollectNFT nft = CollectNFT(hub.getCollectNFT(firstProfileId, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), me);

        string memory expectedName = string(
            abi.encodePacked(mockHandle, COLLECT_NFT_NAME_INFIX, '1')
        );
        string memory expectedSymbol = string(
            abi.encodePacked(bytes4(bytes(mockHandle)), COLLECT_NFT_SYMBOL_INFIX, '1')
        );

        assertEq(nft.name(), expectedName);
        assertEq(nft.symbol(), expectedSymbol);
    }

    function testExecutorCollect() public {
        hub.setDelegatedExecutorApproval(otherSigner, true);

        vm.prank(otherSigner);
        uint256 nftId = hub.collect(me, firstProfileId, 1, '');

        CollectNFT nft = CollectNFT(hub.getCollectNFT(firstProfileId, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), me);
    }

    function testCollectMirror() public {
        vm.prank(profileOwner);
        hub.mirror(mockMirrorData);

        uint256 nftId = hub.collect(me, firstProfileId, 2, '');

        // Ensure the mirror doesn't have an associated collect NFT.
        assertEq(hub.getCollectNFT(firstProfileId, 2), address(0));

        // Ensure the original publication does have an associated collect NFT.
        CollectNFT nft = CollectNFT(hub.getCollectNFT(firstProfileId, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), me);
    }

    function testExecutorCollectMirror() public {
        vm.prank(profileOwner);
        hub.mirror(mockMirrorData);

        hub.setDelegatedExecutorApproval(otherSigner, true);

        vm.prank(otherSigner);
        uint256 nftId = hub.collect(me, firstProfileId, 2, '');

        // Ensure the mirror doesn't have an associated collect NFT.
        assertEq(hub.getCollectNFT(firstProfileId, 2), address(0));

        // Ensure the original publication does have an associated collect NFT.
        CollectNFT nft = CollectNFT(hub.getCollectNFT(firstProfileId, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), me);
    }

    // Meta-tx
    // negatives
    function testCollectWithSigInvalidSignerFails() public {
        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        bytes32 digest = _getCollectTypedDataHash(firstProfileId, 1, '', nonce, deadline);
        vm.expectRevert(Errors.SignatureInvalid.selector);
        hub.collectWithSig(
            _buildCollectWithSigData({
                delegatedSigner: address(0),
                collector: profileOwner,
                profileId: firstProfileId,
                pubId: 1,
                data: '',
                sig: _getSigStruct(otherSignerKey, digest, deadline)
            })
        );
    }

    function testCollectWithSigNotExecutorFails() public {
        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        bytes32 digest = _getCollectTypedDataHash(firstProfileId, 1, '', nonce, deadline);
        vm.expectRevert(Errors.ExecutorInvalid.selector);
        hub.collectWithSig(
            _buildCollectWithSigData({
                delegatedSigner: otherSigner,
                collector: profileOwner,
                profileId: firstProfileId,
                pubId: 1,
                data: '',
                sig: _getSigStruct(otherSignerKey, digest, deadline)
            })
        );
    }

    // positives
    function testCollectWithSig() public {
        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        bytes32 digest = _getCollectTypedDataHash(firstProfileId, 1, '', nonce, deadline);
        uint256 nftId = hub.collectWithSig(
            _buildCollectWithSigData({
                delegatedSigner: address(0),
                collector: otherSigner,
                profileId: firstProfileId,
                pubId: 1,
                data: '',
                sig: _getSigStruct(otherSignerKey, digest, deadline)
            })
        );

        CollectNFT nft = CollectNFT(hub.getCollectNFT(firstProfileId, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), otherSigner);
    }

    function testCollectWithSigMirror() public {
        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        bytes32 digest = _getCollectTypedDataHash(firstProfileId, 2, '', nonce, deadline);

        vm.prank(profileOwner);
        hub.mirror(mockMirrorData);

        uint256 nftId = hub.collectWithSig(
            _buildCollectWithSigData({
                delegatedSigner: address(0),
                collector: otherSigner,
                profileId: firstProfileId,
                pubId: 2,
                data: '',
                sig: _getSigStruct(otherSignerKey, digest, deadline)
            })
        );

        // Ensure the mirror doesn't have an associated collect NFT.
        assertEq(hub.getCollectNFT(firstProfileId, 2), address(0));

        // Ensure the original publication does have an associated collect NFT.
        CollectNFT nft = CollectNFT(hub.getCollectNFT(1, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), otherSigner);
    }

    function testExecutorCollectWithSig() public {
        vm.prank(otherSigner);
        hub.setDelegatedExecutorApproval(profileOwner, true);

        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        bytes32 digest = _getCollectTypedDataHash(firstProfileId, 1, '', nonce, deadline);
        uint256 nftId = hub.collectWithSig(
            _buildCollectWithSigData({
                delegatedSigner: profileOwner,
                collector: otherSigner,
                profileId: firstProfileId,
                pubId: 1,
                data: '',
                sig: _getSigStruct(profileOwnerKey, digest, deadline)
            })
        );

        CollectNFT nft = CollectNFT(hub.getCollectNFT(firstProfileId, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), otherSigner);
    }

    function testExecutorCollectWithSigMirror() public {
        vm.prank(otherSigner);
        hub.setDelegatedExecutorApproval(profileOwner, true);

        uint256 nonce = 0;
        uint256 deadline = type(uint256).max;
        bytes32 digest = _getCollectTypedDataHash(firstProfileId, 2, '', nonce, deadline);

        vm.prank(profileOwner);
        hub.mirror(mockMirrorData);

        uint256 nftId = hub.collectWithSig(
            _buildCollectWithSigData({
                delegatedSigner: profileOwner,
                collector: otherSigner,
                profileId: firstProfileId,
                pubId: 2,
                data: '',
                sig: _getSigStruct(profileOwnerKey, digest, deadline)
            })
        );

        // Ensure the mirror doesn't have an associated collect NFT.
        assertEq(hub.getCollectNFT(firstProfileId, 2), address(0));

        // Ensure the original publication does have an associated collect NFT.
        CollectNFT nft = CollectNFT(hub.getCollectNFT(1, 1));
        assertEq(nftId, 1);
        assertEq(nft.ownerOf(1), otherSigner);
    }

    // Private functions
    function _buildCollectWithSigData(
        address delegatedSigner,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes memory data,
        DataTypes.EIP712Signature memory sig
    ) private pure returns (DataTypes.CollectWithSigData memory) {
        return
            DataTypes.CollectWithSigData(delegatedSigner, collector, profileId, pubId, data, sig);
    }
}
