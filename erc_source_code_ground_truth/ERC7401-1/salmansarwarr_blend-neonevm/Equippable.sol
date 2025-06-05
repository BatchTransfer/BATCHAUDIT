// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./RMRKEquippable.sol";
import "./RMRKSoulboundPerToken.sol";
import "./RMRKCatalog.sol";

contract Equippale is
    RMRKEquippable,
    RMRKSoulboundPerToken,
    RMRKCatalog("google.com", "slot")
{
    uint64 tokenId = 1;
    uint64 childId = 1;
    uint64 assetId = 1;
    uint64 groupId = 1;
    uint64 partId = 1;
    uint64[] parentTokens;

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 token_id
    ) internal virtual override(RMRKNestable, RMRKSoulbound) {
        if (!isTransferable(token_id, from, to))
            revert RMRKCannotTransferSoulbound();
    }

    function mint(
        string memory metadataURI,
        address[] memory equippables
    ) public {
        uint64[] memory partIds = new uint64[](3);
        _mint(msg.sender, tokenId, "0x64");
        uint64 length = partId + 3;
        uint index = 0;
        for (uint64 parts = partId; parts < length; parts++) {
            addPart(equippables, metadataURI, parts);
            partIds[index] = parts;
            index++;
            partId++;
        }
        _addAssetEntry(tokenId, groupId, address(this), metadataURI, partIds);
        _addAssetToToken(tokenId, assetId, assetId);
        _acceptAsset(tokenId, 0, assetId);
        parentTokens.push(tokenId);
        tokenId++;
        assetId++;
    }

    function getParentTokens() public view returns (uint64[] memory) {
        return parentTokens;
    }

    function mintChild(uint64 token_id, string memory metadataURI) public {
        uint64[] memory part;
        _mint(msg.sender, tokenId, "0x64");
        _addAssetEntry(tokenId, groupId, address(this), metadataURI, part);
        _addAssetToToken(tokenId, assetId, assetId);
        _acceptAsset(tokenId, 0, assetId);
        addChild(token_id, tokenId);
        acceptChild(token_id, 0, address(this), tokenId);
        tokenId++;
        assetId++;
    }

    function addChild(uint64 token_id, uint64 child_id) internal {
        IERC7401 destContract = IERC7401(address(this));
        destContract.addChild(token_id, child_id, "0x64");
    }

    function addPart(
        address[] memory equippables,
        string memory metadataURI,
        uint64 _partId
    ) public {
        Part memory partData = Part({
            itemType: ItemType.Slot,
            z: 2,
            equippable: equippables,
            metadataURI: metadataURI
        });
        IntakeStruct memory partIntake = IntakeStruct({
            partId: partId,
            part: partData
        });
        _addPart(partIntake);
        _setEquippableToAll(_partId);
    }

    function equipToken(
        uint64 equippableGroupId,
        address parentAddress,
        uint64 slotPartId,
        IntakeEquip memory data
    ) public {
        setValidParentForEquippableGroup(
            equippableGroupId,
            parentAddress,
            slotPartId
        );
        equip(data);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(RMRKEquippable, RMRKSoulbound, RMRKCatalog)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setValidParentForEquippableGroup(
        uint64 equippableGroupId,
        address parentAddress,
        uint64 slotPartId
    ) public {
        _setValidParentForEquippableGroup(
            equippableGroupId,
            parentAddress,
            slotPartId
        );
    }

    function getTokenId() public view returns (uint64) {
        return tokenId;
    }
}
