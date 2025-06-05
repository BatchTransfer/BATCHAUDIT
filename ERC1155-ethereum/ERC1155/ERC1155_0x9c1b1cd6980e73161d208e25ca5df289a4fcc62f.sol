// File: _4ChanX.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "operator-filter-registry/src/RevokableOperatorFilterer.sol";

/**
 * @author Created with HeyMint Launchpad https://launchpad.heymint.xyz
 * @notice This contract handles minting $4Chan X tokens.
 */
contract _4ChanX is
    ERC1155Supply,
    Ownable,
    Pausable,
    ReentrancyGuard,
    ERC2981,
    RevokableOperatorFilterer
{
    using ECDSA for bytes32;

    // Default address to subscribe to for determining blocklisted exchanges
    address constant DEFAULT_SUBSCRIPTION =
        address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);
    // Used to validate authorized presale mint addresses
    address private presaleSignerAddress =
        0x110EA37D6BF74063708022c7562549C1a9314522;
    // Address where HeyMint fees are sent
    address public heymintPayoutAddress =
        0xE1FaC470dE8dE91c66778eaa155C64c7ceEFc851;
    address public royaltyAddress = 0xFA1030B5625623352E2c07F7A0B1bb601fca6344;
    address[] public paperAddresses = [
        0xf3DB642663231887E2Ff3501da6E3247D8634A6D,
        0x5e01a33C75931aD0A91A12Ee016Be8D61b24ADEB,
        0x9E733848061e4966c4a920d5b99a123459670aEe,
        0x7754B94345BCE520f8dd4F6a5642567603e90E10
    ];
    address[] public payoutAddresses = [
        0xFA1030B5625623352E2c07F7A0B1bb601fca6344
    ];
    // Permanently freezes metadata for all tokens so they can never be changed
    bool public allMetadataFrozen = false;
    // If true, payout addresses and basis points are permanently frozen and can never be updated
    bool public payoutAddressesFrozen;
    // The amount of tokens minted by a given address for a given token id
    mapping(address => mapping(uint256 => uint256))
        public tokensMintedByAddress;
    // Permanently freezes metadata for a specific token id so it can never be changed
    mapping(uint256 => bool) public tokenMetadataFrozen;
    // If true, the given token id can never be minted again
    mapping(uint256 => bool) public tokenMintingPermanentlyDisabled;
    mapping(uint256 => bool) public tokenPresaleSaleActive;
    mapping(uint256 => bool) public tokenPublicSaleActive;
    // If true, sale start and end times for the presale will be enforced, else ignored
    mapping(uint256 => bool) public tokenUsePresaleTimes;
    // If true, sale start and end times for the public sale will be enforced, else ignored
    mapping(uint256 => bool) public tokenUsePublicSaleTimes;
    mapping(uint256 => string) public tokenURI;
    // Maximum supply of tokens that can be minted for each token id. If zero, this token is open edition and has no mint limit
    mapping(uint256 => uint256) public tokenMaxSupply;
    // If zero, this token is open edition and has no mint limit
    mapping(uint256 => uint256) public tokenPresaleMaxSupply;
    mapping(uint256 => uint256) public tokenPresaleMintsPerAddress;
    mapping(uint256 => uint256) public tokenPresalePrice;
    mapping(uint256 => uint256) public tokenPresaleSaleEndTime;
    mapping(uint256 => uint256) public tokenPresaleSaleStartTime;
    mapping(uint256 => uint256) public tokenPublicMintsPerAddress;
    mapping(uint256 => uint256) public tokenPublicPrice;
    mapping(uint256 => uint256) public tokenPublicSaleEndTime;
    mapping(uint256 => uint256) public tokenPublicSaleStartTime;
    string public name = "$4Chan X";
    string public symbol = "4CX";
    // Fee paid to HeyMint per NFT minted
    uint256 public heymintFeePerToken;
    // The respective share of funds to be sent to each address in payoutAddresses in basis points
    uint256[] public payoutBasisPoints = [10000];
    uint96 public royaltyFee = 1000;

    constructor(
        uint256 _heymintFeePerToken
    )
        ERC1155(
            "ipfs://bafybeif2da74gdkn25bzmslnhkdthymhgjlvivhdvqnqa3nu57fwydwx4u/{id}"
        )
        RevokableOperatorFilterer(
            0x000000000000AAeB6D7670E522A718067333cd4E,
            DEFAULT_SUBSCRIPTION,
            true
        )
    {
        heymintFeePerToken = _heymintFeePerToken;
        _setDefaultRoyalty(royaltyAddress, royaltyFee);
        tokenMaxSupply[1] = 1;
        tokenPublicPrice[1] = 0.03 ether;
        tokenPublicMintsPerAddress[1] = 1;
        tokenMaxSupply[2] = 1;
        tokenPublicPrice[2] = 0.03 ether;
        tokenPublicMintsPerAddress[2] = 1;
        tokenMaxSupply[3] = 1;
        tokenPublicPrice[3] = 0.03 ether;
        tokenPublicMintsPerAddress[3] = 1;
        tokenMaxSupply[5] = 1;
        tokenPublicPrice[5] = 0.03 ether;
        tokenPublicMintsPerAddress[5] = 1;
        tokenMaxSupply[6] = 1;
        tokenPublicPrice[6] = 0.03 ether;
        tokenPublicMintsPerAddress[6] = 1;
        tokenMaxSupply[7] = 1;
        tokenPublicPrice[7] = 0.03 ether;
        tokenPublicMintsPerAddress[7] = 1;
        tokenMaxSupply[8] = 1;
        tokenPublicPrice[8] = 0.03 ether;
        tokenPublicMintsPerAddress[8] = 1;
        tokenMaxSupply[9] = 1;
        tokenPublicPrice[9] = 0.03 ether;
        tokenPublicMintsPerAddress[9] = 1;
        tokenMaxSupply[10] = 1;
        tokenPublicPrice[10] = 0.03 ether;
        tokenPublicMintsPerAddress[10] = 1;
        tokenMaxSupply[11] = 1;
        tokenPublicPrice[11] = 0.03 ether;
        tokenPublicMintsPerAddress[11] = 1;
        tokenMaxSupply[12] = 1;
        tokenPublicPrice[12] = 0.03 ether;
        tokenPublicMintsPerAddress[12] = 1;
        tokenMaxSupply[13] = 1;
        tokenPublicPrice[13] = 0.03 ether;
        tokenPublicMintsPerAddress[13] = 1;
        tokenMaxSupply[14] = 1;
        tokenPublicPrice[14] = 0.03 ether;
        tokenPublicMintsPerAddress[14] = 1;
        tokenMaxSupply[16] = 1;
        tokenPublicPrice[16] = 0.03 ether;
        tokenPublicMintsPerAddress[16] = 1;
        tokenMaxSupply[17] = 1;
        tokenPublicPrice[17] = 0.03 ether;
        tokenPublicMintsPerAddress[17] = 1;
        tokenMaxSupply[18] = 1;
        tokenPublicPrice[18] = 0.03 ether;
        tokenPublicMintsPerAddress[18] = 1;
        tokenMaxSupply[19] = 1;
        tokenPublicPrice[19] = 0.03 ether;
        tokenPublicMintsPerAddress[19] = 1;
        tokenMaxSupply[20] = 1;
        tokenPublicPrice[20] = 0.03 ether;
        tokenPublicMintsPerAddress[20] = 1;
        tokenMaxSupply[21] = 1;
        tokenPublicPrice[21] = 0.03 ether;
        tokenPublicMintsPerAddress[21] = 1;
        tokenMaxSupply[22] = 1;
        tokenPublicPrice[22] = 0.03 ether;
        tokenPublicMintsPerAddress[22] = 1;
        tokenMaxSupply[23] = 1;
        tokenPublicPrice[23] = 0.03 ether;
        tokenPublicMintsPerAddress[23] = 1;
        tokenMaxSupply[24] = 1;
        tokenPublicPrice[24] = 0.03 ether;
        tokenPublicMintsPerAddress[24] = 1;
        tokenMaxSupply[25] = 1;
        tokenPublicPrice[25] = 0.03 ether;
        tokenPublicMintsPerAddress[25] = 1;
        tokenMaxSupply[26] = 1;
        tokenPublicPrice[26] = 0.03 ether;
        tokenPublicMintsPerAddress[26] = 1;
        tokenMaxSupply[27] = 1;
        tokenPublicPrice[27] = 0.03 ether;
        tokenPublicMintsPerAddress[27] = 1;
        tokenMaxSupply[28] = 1;
        tokenPublicPrice[28] = 0.03 ether;
        tokenPublicMintsPerAddress[28] = 1;
        tokenMaxSupply[29] = 1;
        tokenPublicPrice[29] = 0.03 ether;
        tokenPublicMintsPerAddress[29] = 1;
        tokenMaxSupply[30] = 1;
        tokenPublicPrice[30] = 0.03 ether;
        tokenPublicMintsPerAddress[30] = 1;
        tokenMaxSupply[31] = 1;
        tokenPublicPrice[31] = 0.03 ether;
        tokenPublicMintsPerAddress[31] = 1;
        tokenMaxSupply[32] = 1;
        tokenPublicPrice[32] = 0.03 ether;
        tokenPublicMintsPerAddress[32] = 1;
        tokenMaxSupply[33] = 1;
        tokenPublicPrice[33] = 0.03 ether;
        tokenPublicMintsPerAddress[33] = 1;
        tokenMaxSupply[34] = 1;
        tokenPublicPrice[34] = 0.03 ether;
        tokenPublicMintsPerAddress[34] = 1;
        tokenMaxSupply[35] = 1;
        tokenPublicPrice[35] = 0.03 ether;
        tokenPublicMintsPerAddress[35] = 1;
        tokenMaxSupply[36] = 1;
        tokenPublicPrice[36] = 0.03 ether;
        tokenPublicMintsPerAddress[36] = 1;
        tokenMaxSupply[37] = 1;
        tokenPublicPrice[37] = 0.03 ether;
        tokenPublicMintsPerAddress[37] = 1;
        tokenMaxSupply[38] = 1;
        tokenPublicPrice[38] = 0.03 ether;
        tokenPublicMintsPerAddress[38] = 1;
        tokenMaxSupply[39] = 1;
        tokenPublicPrice[39] = 0.03 ether;
        tokenPublicMintsPerAddress[39] = 1;
        tokenMaxSupply[40] = 1;
        tokenPublicPrice[40] = 0.03 ether;
        tokenPublicMintsPerAddress[40] = 1;
        tokenMaxSupply[41] = 1;
        tokenPublicPrice[41] = 0.03 ether;
        tokenPublicMintsPerAddress[41] = 1;
        tokenMaxSupply[42] = 1;
        tokenPublicPrice[42] = 0.03 ether;
        tokenPublicMintsPerAddress[42] = 1;
        tokenMaxSupply[44] = 1;
        tokenPublicPrice[44] = 0.03 ether;
        tokenPublicMintsPerAddress[44] = 1;
        tokenMaxSupply[45] = 1;
        tokenPublicPrice[45] = 0.03 ether;
        tokenPublicMintsPerAddress[45] = 1;
        tokenMaxSupply[46] = 1;
        tokenPublicPrice[46] = 0.03 ether;
        tokenPublicMintsPerAddress[46] = 1;
        tokenMaxSupply[49] = 1;
        tokenPublicPrice[49] = 0.03 ether;
        tokenPublicMintsPerAddress[49] = 1;
        tokenMaxSupply[50] = 1;
        tokenPublicPrice[50] = 0.03 ether;
        tokenPublicMintsPerAddress[50] = 1;
        tokenMaxSupply[51] = 1;
        tokenPublicPrice[51] = 0.03 ether;
        tokenPublicMintsPerAddress[51] = 1;
        tokenMaxSupply[52] = 1;
        tokenPublicPrice[52] = 0.03 ether;
        tokenPublicMintsPerAddress[52] = 1;
        tokenMaxSupply[53] = 1;
        tokenPublicPrice[53] = 0.03 ether;
        tokenPublicMintsPerAddress[53] = 1;
        tokenMaxSupply[54] = 1;
        tokenPublicPrice[54] = 0.03 ether;
        tokenPublicMintsPerAddress[54] = 1;
        tokenMaxSupply[56] = 1;
        tokenPublicPrice[56] = 0.03 ether;
        tokenPublicMintsPerAddress[56] = 1;
        tokenMaxSupply[57] = 1;
        tokenPublicPrice[57] = 0.03 ether;
        tokenPublicMintsPerAddress[57] = 1;
        tokenMaxSupply[59] = 1;
        tokenPublicPrice[59] = 0.03 ether;
        tokenPublicMintsPerAddress[59] = 1;
        tokenMaxSupply[60] = 1;
        tokenPublicPrice[60] = 0.03 ether;
        tokenPublicMintsPerAddress[60] = 1;
        tokenMaxSupply[61] = 1;
        tokenPublicPrice[61] = 0.03 ether;
        tokenPublicMintsPerAddress[61] = 1;
        tokenMaxSupply[62] = 1;
        tokenPublicPrice[62] = 0.03 ether;
        tokenPublicMintsPerAddress[62] = 1;
        tokenMaxSupply[65] = 1;
        tokenPublicPrice[65] = 0.03 ether;
        tokenPublicMintsPerAddress[65] = 1;
        tokenMaxSupply[66] = 1;
        tokenPublicPrice[66] = 0.03 ether;
        tokenPublicMintsPerAddress[66] = 1;
        tokenMaxSupply[69] = 1;
        tokenPublicPrice[69] = 0.03 ether;
        tokenPublicMintsPerAddress[69] = 1;
        tokenMaxSupply[70] = 1;
        tokenPublicPrice[70] = 0.03 ether;
        tokenPublicMintsPerAddress[70] = 1;
        tokenMaxSupply[72] = 1;
        tokenPublicPrice[72] = 0.03 ether;
        tokenPublicMintsPerAddress[72] = 1;
        tokenMaxSupply[73] = 1;
        tokenPublicPrice[73] = 0.03 ether;
        tokenPublicMintsPerAddress[73] = 1;
        tokenMaxSupply[74] = 1;
        tokenPublicPrice[74] = 0.03 ether;
        tokenPublicMintsPerAddress[74] = 1;
        tokenMaxSupply[76] = 1;
        tokenPublicPrice[76] = 0.03 ether;
        tokenPublicMintsPerAddress[76] = 1;
        tokenMaxSupply[77] = 1;
        tokenPublicPrice[77] = 0.03 ether;
        tokenPublicMintsPerAddress[77] = 1;
        tokenMaxSupply[78] = 1;
        tokenPublicPrice[78] = 0.03 ether;
        tokenPublicMintsPerAddress[78] = 1;
        tokenMaxSupply[79] = 1;
        tokenPublicPrice[79] = 0.03 ether;
        tokenPublicMintsPerAddress[79] = 1;
        tokenMaxSupply[80] = 1;
        tokenPublicPrice[80] = 0.03 ether;
        tokenPublicMintsPerAddress[80] = 1;
        tokenMaxSupply[81] = 1;
        tokenPublicPrice[81] = 0.03 ether;
        tokenPublicMintsPerAddress[81] = 1;
        tokenMaxSupply[82] = 1;
        tokenPublicPrice[82] = 0.03 ether;
        tokenPublicMintsPerAddress[82] = 1;
        tokenMaxSupply[83] = 1;
        tokenPublicPrice[83] = 0.03 ether;
        tokenPublicMintsPerAddress[83] = 1;
        tokenMaxSupply[84] = 1;
        tokenPublicPrice[84] = 0.03 ether;
        tokenPublicMintsPerAddress[84] = 1;
        tokenMaxSupply[85] = 1;
        tokenPublicPrice[85] = 0.03 ether;
        tokenPublicMintsPerAddress[85] = 1;
        tokenMaxSupply[86] = 1;
        tokenPublicPrice[86] = 0.03 ether;
        tokenPublicMintsPerAddress[86] = 1;
        tokenMaxSupply[88] = 1;
        tokenPublicPrice[88] = 0.03 ether;
        tokenPublicMintsPerAddress[88] = 1;
        tokenMaxSupply[89] = 1;
        tokenPublicPrice[89] = 0.03 ether;
        tokenPublicMintsPerAddress[89] = 1;
        tokenMaxSupply[90] = 1;
        tokenPublicPrice[90] = 0.03 ether;
        tokenPublicMintsPerAddress[90] = 1;
        tokenMaxSupply[91] = 1;
        tokenPublicPrice[91] = 0.03 ether;
        tokenPublicMintsPerAddress[91] = 1;
        tokenMaxSupply[92] = 1;
        tokenPublicPrice[92] = 0.03 ether;
        tokenPublicMintsPerAddress[92] = 1;
        tokenMaxSupply[93] = 1;
        tokenPublicPrice[93] = 0.03 ether;
        tokenPublicMintsPerAddress[93] = 1;
        tokenMaxSupply[94] = 1;
        tokenPublicPrice[94] = 0.03 ether;
        tokenPublicMintsPerAddress[94] = 1;
        tokenMaxSupply[95] = 1;
        tokenPublicPrice[95] = 0.03 ether;
        tokenPublicMintsPerAddress[95] = 1;
        tokenMaxSupply[96] = 1;
        tokenPublicPrice[96] = 0.03 ether;
        tokenPublicMintsPerAddress[96] = 1;
        tokenMaxSupply[97] = 1;
        tokenPublicPrice[97] = 0.03 ether;
        tokenPublicMintsPerAddress[97] = 1;
        tokenMaxSupply[98] = 1;
        tokenPublicPrice[98] = 0.03 ether;
        tokenPublicMintsPerAddress[98] = 1;
        tokenMaxSupply[100] = 1;
        tokenPublicPrice[100] = 0.03 ether;
        tokenPublicMintsPerAddress[100] = 1;
        tokenMaxSupply[101] = 1;
        tokenPublicPrice[101] = 0.03 ether;
        tokenPublicMintsPerAddress[101] = 1;
        tokenMaxSupply[102] = 1;
        tokenPublicPrice[102] = 0.03 ether;
        tokenPublicMintsPerAddress[102] = 1;
        tokenMaxSupply[103] = 1;
        tokenPublicPrice[103] = 0.03 ether;
        tokenPublicMintsPerAddress[103] = 1;
        tokenMaxSupply[104] = 1;
        tokenPublicPrice[104] = 0.03 ether;
        tokenPublicMintsPerAddress[104] = 1;
        tokenMaxSupply[105] = 1;
        tokenPublicPrice[105] = 0.03 ether;
        tokenPublicMintsPerAddress[105] = 1;
        tokenMaxSupply[106] = 1;
        tokenPublicPrice[106] = 0.03 ether;
        tokenPublicMintsPerAddress[106] = 1;
        tokenMaxSupply[108] = 1;
        tokenPublicPrice[108] = 0.03 ether;
        tokenPublicMintsPerAddress[108] = 1;
        tokenMaxSupply[109] = 1;
        tokenPublicPrice[109] = 0.03 ether;
        tokenPublicMintsPerAddress[109] = 1;
        tokenMaxSupply[110] = 1;
        tokenPublicPrice[110] = 0.03 ether;
        tokenPublicMintsPerAddress[110] = 1;
        tokenMaxSupply[111] = 1;
        tokenPublicPrice[111] = 0.03 ether;
        tokenPublicMintsPerAddress[111] = 1;
        tokenMaxSupply[112] = 1;
        tokenPublicPrice[112] = 0.03 ether;
        tokenPublicMintsPerAddress[112] = 1;
        tokenMaxSupply[113] = 1;
        tokenPublicPrice[113] = 0.03 ether;
        tokenPublicMintsPerAddress[113] = 1;
        tokenMaxSupply[114] = 1;
        tokenPublicPrice[114] = 0.03 ether;
        tokenPublicMintsPerAddress[114] = 1;
        tokenMaxSupply[115] = 1;
        tokenPublicPrice[115] = 0.03 ether;
        tokenPublicMintsPerAddress[115] = 1;
        tokenMaxSupply[116] = 1;
        tokenPublicPrice[116] = 0.03 ether;
        tokenPublicMintsPerAddress[116] = 1;
        tokenMaxSupply[117] = 1;
        tokenPublicPrice[117] = 0.03 ether;
        tokenPublicMintsPerAddress[117] = 1;
        tokenMaxSupply[118] = 1;
        tokenPublicPrice[118] = 0.03 ether;
        tokenPublicMintsPerAddress[118] = 1;
        tokenMaxSupply[120] = 1;
        tokenPublicPrice[120] = 0.03 ether;
        tokenPublicMintsPerAddress[120] = 1;
        tokenMaxSupply[121] = 1;
        tokenPublicPrice[121] = 0.03 ether;
        tokenPublicMintsPerAddress[121] = 1;
        tokenMaxSupply[122] = 1;
        tokenPublicPrice[122] = 0.03 ether;
        tokenPublicMintsPerAddress[122] = 1;
        tokenMaxSupply[123] = 1;
        tokenPublicPrice[123] = 0.03 ether;
        tokenPublicMintsPerAddress[123] = 1;
        tokenMaxSupply[124] = 1;
        tokenPublicPrice[124] = 0.03 ether;
        tokenPublicMintsPerAddress[124] = 1;
        tokenMaxSupply[125] = 1;
        tokenPublicPrice[125] = 0.03 ether;
        tokenPublicMintsPerAddress[125] = 1;
        tokenMaxSupply[126] = 1;
        tokenPublicPrice[126] = 0.03 ether;
        tokenPublicMintsPerAddress[126] = 1;
        tokenMaxSupply[127] = 1;
        tokenPublicPrice[127] = 0.03 ether;
        tokenPublicMintsPerAddress[127] = 1;
        tokenMaxSupply[129] = 1;
        tokenPublicPrice[129] = 0.03 ether;
        tokenPublicMintsPerAddress[129] = 1;
        tokenMaxSupply[130] = 1;
        tokenPublicPrice[130] = 0.03 ether;
        tokenPublicMintsPerAddress[130] = 1;
        tokenMaxSupply[131] = 1;
        tokenPublicPrice[131] = 0.03 ether;
        tokenPublicMintsPerAddress[131] = 1;
        tokenMaxSupply[132] = 1;
        tokenPublicPrice[132] = 0.03 ether;
        tokenPublicMintsPerAddress[132] = 1;
        tokenMaxSupply[134] = 1;
        tokenPublicPrice[134] = 0.03 ether;
        tokenPublicMintsPerAddress[134] = 1;
        tokenMaxSupply[135] = 1;
        tokenPublicPrice[135] = 0.03 ether;
        tokenPublicMintsPerAddress[135] = 1;
        tokenMaxSupply[136] = 1;
        tokenPublicPrice[136] = 0.03 ether;
        tokenPublicMintsPerAddress[136] = 1;
        tokenMaxSupply[137] = 1;
        tokenPublicPrice[137] = 0.03 ether;
        tokenPublicMintsPerAddress[137] = 1;
        tokenMaxSupply[138] = 1;
        tokenPublicPrice[138] = 0.03 ether;
        tokenPublicMintsPerAddress[138] = 1;
        tokenMaxSupply[139] = 1;
        tokenPublicPrice[139] = 0.03 ether;
        tokenPublicMintsPerAddress[139] = 1;
        tokenMaxSupply[140] = 1;
        tokenPublicPrice[140] = 0.03 ether;
        tokenPublicMintsPerAddress[140] = 1;
        tokenMaxSupply[141] = 1;
        tokenPublicPrice[141] = 0.03 ether;
        tokenPublicMintsPerAddress[141] = 1;
        tokenMaxSupply[142] = 1;
        tokenPublicPrice[142] = 0.03 ether;
        tokenPublicMintsPerAddress[142] = 1;
        tokenMaxSupply[144] = 1;
        tokenPublicPrice[144] = 0.03 ether;
        tokenPublicMintsPerAddress[144] = 1;
        tokenMaxSupply[145] = 1;
        tokenPublicPrice[145] = 0.03 ether;
        tokenPublicMintsPerAddress[145] = 1;
        tokenMaxSupply[146] = 1;
        tokenPublicPrice[146] = 0.03 ether;
        tokenPublicMintsPerAddress[146] = 1;
        tokenMaxSupply[147] = 1;
        tokenPublicPrice[147] = 0.03 ether;
        tokenPublicMintsPerAddress[147] = 1;
        tokenMaxSupply[148] = 1;
        tokenPublicPrice[148] = 0.03 ether;
        tokenPublicMintsPerAddress[148] = 1;
        tokenMaxSupply[149] = 1;
        tokenPublicPrice[149] = 0.03 ether;
        tokenPublicMintsPerAddress[149] = 1;
        tokenMaxSupply[151] = 1;
        tokenPublicPrice[151] = 0.03 ether;
        tokenPublicMintsPerAddress[151] = 1;
        tokenMaxSupply[152] = 1;
        tokenPublicPrice[152] = 0.03 ether;
        tokenPublicMintsPerAddress[152] = 1;
        tokenMaxSupply[153] = 1;
        tokenPublicPrice[153] = 0.03 ether;
        tokenPublicMintsPerAddress[153] = 1;
        tokenMaxSupply[154] = 1;
        tokenPublicPrice[154] = 0.03 ether;
        tokenPublicMintsPerAddress[154] = 1;
        tokenMaxSupply[155] = 1;
        tokenPublicPrice[155] = 0.03 ether;
        tokenPublicMintsPerAddress[155] = 1;
        tokenMaxSupply[157] = 1;
        tokenPublicPrice[157] = 0.03 ether;
        tokenPublicMintsPerAddress[157] = 1;
        tokenMaxSupply[158] = 1;
        tokenPublicPrice[158] = 0.03 ether;
        tokenPublicMintsPerAddress[158] = 1;
        tokenMaxSupply[159] = 1;
        tokenPublicPrice[159] = 0.03 ether;
        tokenPublicMintsPerAddress[159] = 1;
        tokenMaxSupply[160] = 1;
        tokenPublicPrice[160] = 0.03 ether;
        tokenPublicMintsPerAddress[160] = 1;
        tokenMaxSupply[162] = 1;
        tokenPublicPrice[162] = 0.03 ether;
        tokenPublicMintsPerAddress[162] = 1;
        tokenMaxSupply[164] = 1;
        tokenPublicPrice[164] = 0.03 ether;
        tokenPublicMintsPerAddress[164] = 1;
        tokenMaxSupply[166] = 1;
        tokenPublicPrice[166] = 0.03 ether;
        tokenPublicMintsPerAddress[166] = 1;
        tokenMaxSupply[167] = 1;
        tokenPublicPrice[167] = 0.03 ether;
        tokenPublicMintsPerAddress[167] = 1;
        tokenMaxSupply[170] = 1;
        tokenPublicPrice[170] = 0.03 ether;
        tokenPublicMintsPerAddress[170] = 1;
        tokenMaxSupply[171] = 1;
        tokenPublicPrice[171] = 0.03 ether;
        tokenPublicMintsPerAddress[171] = 1;
        tokenMaxSupply[172] = 1;
        tokenPublicPrice[172] = 0.03 ether;
        tokenPublicMintsPerAddress[172] = 1;
        tokenMaxSupply[173] = 1;
        tokenPublicPrice[173] = 0.03 ether;
        tokenPublicMintsPerAddress[173] = 1;
        tokenMaxSupply[175] = 1;
        tokenPublicPrice[175] = 0.03 ether;
        tokenPublicMintsPerAddress[175] = 1;
        tokenMaxSupply[176] = 1;
        tokenPublicPrice[176] = 0.03 ether;
        tokenPublicMintsPerAddress[176] = 1;
        tokenMaxSupply[177] = 1;
        tokenPublicPrice[177] = 0.03 ether;
        tokenPublicMintsPerAddress[177] = 1;
        tokenMaxSupply[178] = 1;
        tokenPublicPrice[178] = 0.03 ether;
        tokenPublicMintsPerAddress[178] = 1;
        tokenMaxSupply[179] = 1;
        tokenPublicPrice[179] = 0.03 ether;
        tokenPublicMintsPerAddress[179] = 1;
        tokenMaxSupply[181] = 1;
        tokenPublicPrice[181] = 0.03 ether;
        tokenPublicMintsPerAddress[181] = 1;
        tokenMaxSupply[182] = 1;
        tokenPublicPrice[182] = 0.03 ether;
        tokenPublicMintsPerAddress[182] = 1;
        tokenMaxSupply[184] = 1;
        tokenPublicPrice[184] = 0.03 ether;
        tokenPublicMintsPerAddress[184] = 1;
        tokenMaxSupply[185] = 1;
        tokenPublicPrice[185] = 0.03 ether;
        tokenPublicMintsPerAddress[185] = 1;
        tokenMaxSupply[186] = 1;
        tokenPublicPrice[186] = 0.03 ether;
        tokenPublicMintsPerAddress[186] = 1;
        tokenMaxSupply[189] = 1;
        tokenPublicPrice[189] = 0.03 ether;
        tokenPublicMintsPerAddress[189] = 1;
        tokenMaxSupply[190] = 1;
        tokenPublicPrice[190] = 0.03 ether;
        tokenPublicMintsPerAddress[190] = 1;
        tokenMaxSupply[192] = 1;
        tokenPublicPrice[192] = 0.03 ether;
        tokenPublicMintsPerAddress[192] = 1;
        tokenMaxSupply[193] = 1;
        tokenPublicPrice[193] = 0.03 ether;
        tokenPublicMintsPerAddress[193] = 1;
        tokenMaxSupply[194] = 1;
        tokenPublicPrice[194] = 0.03 ether;
        tokenPublicMintsPerAddress[194] = 1;
        tokenMaxSupply[196] = 1;
        tokenPublicPrice[196] = 0.03 ether;
        tokenPublicMintsPerAddress[196] = 1;
        tokenMaxSupply[197] = 1;
        tokenPublicPrice[197] = 0.03 ether;
        tokenPublicMintsPerAddress[197] = 1;
        tokenMaxSupply[198] = 1;
        tokenPublicPrice[198] = 0.03 ether;
        tokenPublicMintsPerAddress[198] = 1;
        tokenMaxSupply[200] = 1;
        tokenPublicPrice[200] = 0.03 ether;
        tokenPublicMintsPerAddress[200] = 1;
        tokenMaxSupply[201] = 1;
        tokenPublicPrice[201] = 0.03 ether;
        tokenPublicMintsPerAddress[201] = 1;
        tokenMaxSupply[202] = 1;
        tokenPublicPrice[202] = 0.03 ether;
        tokenPublicMintsPerAddress[202] = 1;
        tokenMaxSupply[203] = 1;
        tokenPublicPrice[203] = 0.03 ether;
        tokenPublicMintsPerAddress[203] = 1;
        tokenMaxSupply[204] = 1;
        tokenPublicPrice[204] = 0.03 ether;
        tokenPublicMintsPerAddress[204] = 1;
        tokenMaxSupply[205] = 1;
        tokenPublicPrice[205] = 0.03 ether;
        tokenPublicMintsPerAddress[205] = 1;
        tokenMaxSupply[208] = 1;
        tokenPublicPrice[208] = 0.03 ether;
        tokenPublicMintsPerAddress[208] = 1;
        tokenMaxSupply[209] = 1;
        tokenPublicPrice[209] = 0.03 ether;
        tokenPublicMintsPerAddress[209] = 1;
        tokenMaxSupply[210] = 1;
        tokenPublicPrice[210] = 0.03 ether;
        tokenPublicMintsPerAddress[210] = 1;
        tokenMaxSupply[212] = 1;
        tokenPublicPrice[212] = 0.03 ether;
        tokenPublicMintsPerAddress[212] = 1;
        tokenMaxSupply[215] = 1;
        tokenPublicPrice[215] = 0.03 ether;
        tokenPublicMintsPerAddress[215] = 1;
        tokenMaxSupply[217] = 1;
        tokenPublicPrice[217] = 0.03 ether;
        tokenPublicMintsPerAddress[217] = 1;
        tokenMaxSupply[218] = 1;
        tokenPublicPrice[218] = 0.03 ether;
        tokenPublicMintsPerAddress[218] = 1;
        tokenMaxSupply[219] = 1;
        tokenPublicPrice[219] = 0.03 ether;
        tokenPublicMintsPerAddress[219] = 1;
        tokenMaxSupply[220] = 1;
        tokenPublicPrice[220] = 0.03 ether;
        tokenPublicMintsPerAddress[220] = 1;
        tokenMaxSupply[221] = 1;
        tokenPublicPrice[221] = 0.03 ether;
        tokenPublicMintsPerAddress[221] = 1;
        tokenMaxSupply[222] = 1;
        tokenPublicPrice[222] = 0.03 ether;
        tokenPublicMintsPerAddress[222] = 1;
        tokenMaxSupply[223] = 1;
        tokenPublicPrice[223] = 0.03 ether;
        tokenPublicMintsPerAddress[223] = 1;
        tokenMaxSupply[224] = 1;
        tokenPublicPrice[224] = 0.03 ether;
        tokenPublicMintsPerAddress[224] = 1;
        tokenMaxSupply[225] = 1;
        tokenPublicPrice[225] = 0.03 ether;
        tokenPublicMintsPerAddress[225] = 1;
        tokenMaxSupply[226] = 1;
        tokenPublicPrice[226] = 0.03 ether;
        tokenPublicMintsPerAddress[226] = 1;
        tokenMaxSupply[230] = 1;
        tokenPublicPrice[230] = 0.03 ether;
        tokenPublicMintsPerAddress[230] = 1;
        tokenMaxSupply[232] = 1;
        tokenPublicPrice[232] = 0.03 ether;
        tokenPublicMintsPerAddress[232] = 1;
        tokenMaxSupply[238] = 1;
        tokenPublicPrice[238] = 0.03 ether;
        tokenPublicMintsPerAddress[238] = 1;
        tokenMaxSupply[239] = 1;
        tokenPublicPrice[239] = 0.03 ether;
        tokenPublicMintsPerAddress[239] = 1;
        tokenMaxSupply[241] = 1;
        tokenPublicPrice[241] = 0.03 ether;
        tokenPublicMintsPerAddress[241] = 1;
        tokenMaxSupply[242] = 1;
        tokenPublicPrice[242] = 0.03 ether;
        tokenPublicMintsPerAddress[242] = 1;
        tokenMaxSupply[246] = 1;
        tokenPublicPrice[246] = 0.03 ether;
        tokenPublicMintsPerAddress[246] = 1;
        tokenMaxSupply[248] = 1;
        tokenPublicPrice[248] = 0.03 ether;
        tokenPublicMintsPerAddress[248] = 1;
        tokenMaxSupply[250] = 1;
        tokenPublicPrice[250] = 0.03 ether;
        tokenPublicMintsPerAddress[250] = 1;
        tokenMaxSupply[252] = 1;
        tokenPublicPrice[252] = 0.03 ether;
        tokenPublicMintsPerAddress[252] = 1;
        tokenMaxSupply[256] = 1;
        tokenPublicPrice[256] = 0.03 ether;
        tokenPublicMintsPerAddress[256] = 1;
        tokenMaxSupply[257] = 1;
        tokenPublicPrice[257] = 0.03 ether;
        tokenPublicMintsPerAddress[257] = 1;
        tokenMaxSupply[258] = 1;
        tokenPublicPrice[258] = 0.03 ether;
        tokenPublicMintsPerAddress[258] = 1;
        tokenMaxSupply[261] = 1;
        tokenPublicPrice[261] = 0.03 ether;
        tokenPublicMintsPerAddress[261] = 1;
        tokenMaxSupply[262] = 1;
        tokenPublicPrice[262] = 0.03 ether;
        tokenPublicMintsPerAddress[262] = 1;
        tokenMaxSupply[263] = 1;
        tokenPublicPrice[263] = 0.03 ether;
        tokenPublicMintsPerAddress[263] = 1;
        tokenMaxSupply[264] = 1;
        tokenPublicPrice[264] = 0.03 ether;
        tokenPublicMintsPerAddress[264] = 1;
        tokenMaxSupply[266] = 1;
        tokenPublicPrice[266] = 0.03 ether;
        tokenPublicMintsPerAddress[266] = 1;
        tokenMaxSupply[273] = 1;
        tokenPublicPrice[273] = 0.03 ether;
        tokenPublicMintsPerAddress[273] = 1;
        tokenMaxSupply[276] = 1;
        tokenPublicPrice[276] = 0.03 ether;
        tokenPublicMintsPerAddress[276] = 1;
        tokenMaxSupply[277] = 1;
        tokenPublicPrice[277] = 0.03 ether;
        tokenPublicMintsPerAddress[277] = 1;
        tokenMaxSupply[279] = 1;
        tokenPublicPrice[279] = 0.03 ether;
        tokenPublicMintsPerAddress[279] = 1;
        tokenMaxSupply[280] = 1;
        tokenPublicPrice[280] = 0.03 ether;
        tokenPublicMintsPerAddress[280] = 1;
        tokenMaxSupply[284] = 1;
        tokenPublicPrice[284] = 0.03 ether;
        tokenPublicMintsPerAddress[284] = 1;
        tokenMaxSupply[285] = 1;
        tokenPublicPrice[285] = 0.03 ether;
        tokenPublicMintsPerAddress[285] = 1;
        tokenMaxSupply[289] = 1;
        tokenPublicPrice[289] = 0.03 ether;
        tokenPublicMintsPerAddress[289] = 1;
        tokenMaxSupply[291] = 1;
        tokenPublicPrice[291] = 0.03 ether;
        tokenPublicMintsPerAddress[291] = 1;
        tokenMaxSupply[292] = 1;
        tokenPublicPrice[292] = 0.03 ether;
        tokenPublicMintsPerAddress[292] = 1;
        tokenMaxSupply[293] = 1;
        tokenPublicPrice[293] = 0.03 ether;
        tokenPublicMintsPerAddress[293] = 1;
        tokenMaxSupply[294] = 1;
        tokenPublicPrice[294] = 0.03 ether;
        tokenPublicMintsPerAddress[294] = 1;
        tokenMaxSupply[296] = 1;
        tokenPublicPrice[296] = 0.03 ether;
        tokenPublicMintsPerAddress[296] = 1;
        tokenMaxSupply[297] = 1;
        tokenPublicPrice[297] = 0.03 ether;
        tokenPublicMintsPerAddress[297] = 1;
        tokenMaxSupply[298] = 1;
        tokenPublicPrice[298] = 0.03 ether;
        tokenPublicMintsPerAddress[298] = 1;
        tokenMaxSupply[300] = 1;
        tokenPublicPrice[300] = 0.03 ether;
        tokenPublicMintsPerAddress[300] = 1;
        tokenMaxSupply[301] = 1;
        tokenPublicPrice[301] = 0.03 ether;
        tokenPublicMintsPerAddress[301] = 1;
        tokenMaxSupply[302] = 1;
        tokenPublicPrice[302] = 0.03 ether;
        tokenPublicMintsPerAddress[302] = 1;
        tokenMaxSupply[303] = 1;
        tokenPublicPrice[303] = 0.03 ether;
        tokenPublicMintsPerAddress[303] = 1;
        tokenMaxSupply[304] = 1;
        tokenPublicPrice[304] = 0.03 ether;
        tokenPublicMintsPerAddress[304] = 1;
        tokenMaxSupply[305] = 1;
        tokenPublicPrice[305] = 0.03 ether;
        tokenPublicMintsPerAddress[305] = 1;
        tokenMaxSupply[306] = 1;
        tokenPublicPrice[306] = 0.03 ether;
        tokenPublicMintsPerAddress[306] = 1;
        tokenMaxSupply[310] = 1;
        tokenPublicPrice[310] = 0.03 ether;
        tokenPublicMintsPerAddress[310] = 1;
        tokenMaxSupply[311] = 1;
        tokenPublicPrice[311] = 0.03 ether;
        tokenPublicMintsPerAddress[311] = 1;
        tokenMaxSupply[312] = 1;
        tokenPublicPrice[312] = 0.03 ether;
        tokenPublicMintsPerAddress[312] = 1;
        tokenMaxSupply[313] = 1;
        tokenPublicPrice[313] = 0.03 ether;
        tokenPublicMintsPerAddress[313] = 1;
        tokenMaxSupply[315] = 1;
        tokenPublicPrice[315] = 0.03 ether;
        tokenPublicMintsPerAddress[315] = 1;
        tokenMaxSupply[316] = 1;
        tokenPublicPrice[316] = 0.03 ether;
        tokenPublicMintsPerAddress[316] = 1;
        tokenMaxSupply[317] = 1;
        tokenPublicPrice[317] = 0.03 ether;
        tokenPublicMintsPerAddress[317] = 1;
        tokenMaxSupply[318] = 1;
        tokenPublicPrice[318] = 0.03 ether;
        tokenPublicMintsPerAddress[318] = 1;
        tokenMaxSupply[319] = 1;
        tokenPublicPrice[319] = 0.03 ether;
        tokenPublicMintsPerAddress[319] = 1;
        tokenMaxSupply[320] = 1;
        tokenPublicPrice[320] = 0.03 ether;
        tokenPublicMintsPerAddress[320] = 1;
        tokenMaxSupply[321] = 1;
        tokenPublicPrice[321] = 0.03 ether;
        tokenPublicMintsPerAddress[321] = 1;
        tokenMaxSupply[325] = 1;
        tokenPublicPrice[325] = 0.03 ether;
        tokenPublicMintsPerAddress[325] = 1;
        tokenMaxSupply[326] = 1;
        tokenPublicPrice[326] = 0.03 ether;
        tokenPublicMintsPerAddress[326] = 1;
        tokenMaxSupply[327] = 1;
        tokenPublicPrice[327] = 0.03 ether;
        tokenPublicMintsPerAddress[327] = 1;
        require(
            payoutAddresses.length == payoutBasisPoints.length,
            "PAYOUT_ARRAYS_NOT_SAME_LENGTH"
        );
        uint256 totalPayoutBasisPoints = 0;
        for (uint256 i = 0; i < payoutBasisPoints.length; i++) {
            totalPayoutBasisPoints += payoutBasisPoints[i];
        }
        require(
            totalPayoutBasisPoints == 10000,
            "TOTAL_BASIS_POINTS_MUST_BE_10000"
        );
    }

    modifier originalUser() {
        require(tx.origin == msg.sender, "CANNOT_CALL_FROM_CONTRACT");
        _;
    }

    /**
     * @notice Returns a custom URI for each token id if set
     */
    function uri(
        uint256 _tokenId
    ) public view override returns (string memory) {
        // If no URI exists for the specific id requested, fallback to the default ERC-1155 URI.
        if (bytes(tokenURI[_tokenId]).length == 0) {
            return super.uri(_tokenId);
        }
        return tokenURI[_tokenId];
    }

    /**
     * @notice Sets a URI for a specific token id.
     */
    function setURI(
        uint256 _tokenId,
        string calldata _newTokenURI
    ) external onlyOwner {
        require(
            !allMetadataFrozen && !tokenMetadataFrozen[_tokenId],
            "METADATA_HAS_BEEN_FROZEN"
        );
        tokenURI[_tokenId] = _newTokenURI;
    }

    /**
     * @notice Update the global default ERC-1155 base URI
     */
    function setGlobalURI(string calldata _newTokenURI) external onlyOwner {
        require(!allMetadataFrozen, "METADATA_HAS_BEEN_FROZEN");
        _setURI(_newTokenURI);
    }

    /**
     * @notice Freeze metadata for a specific token id so it can never be changed again
     */
    function freezeTokenMetadata(uint256 _tokenId) external onlyOwner {
        require(
            !tokenMetadataFrozen[_tokenId],
            "METADATA_HAS_ALREADY_BEEN_FROZEN"
        );
        tokenMetadataFrozen[_tokenId] = true;
    }

    /**
     * @notice Freeze all metadata so it can never be changed again
     */
    function freezeAllMetadata() external onlyOwner {
        require(!allMetadataFrozen, "METADATA_HAS_ALREADY_BEEN_FROZEN");
        allMetadataFrozen = true;
    }

    /**
     * @notice Reduce the max supply of tokens for a given token id
     * @param _newMaxSupply The new maximum supply of tokens available to mint
     * @param _tokenId The token id to reduce the max supply for
     */
    function reduceMaxSupply(
        uint256 _tokenId,
        uint256 _newMaxSupply
    ) external onlyOwner {
        require(
            tokenMaxSupply[_tokenId] == 0 ||
                _newMaxSupply < tokenMaxSupply[_tokenId],
            "NEW_MAX_SUPPLY_TOO_HIGH"
        );
        require(
            _newMaxSupply >= totalSupply(_tokenId),
            "SUPPLY_LOWER_THAN_MINTED_TOKENS"
        );
        tokenMaxSupply[_tokenId] = _newMaxSupply;
    }

    /**
     * @notice Lock a token id so that it can never be minted again
     */
    function permanentlyDisableTokenMinting(
        uint256 _tokenId
    ) external onlyOwner {
        tokenMintingPermanentlyDisabled[_tokenId] = true;
    }

    /**
     * @notice Change the royalty fee for the collection
     */
    function setRoyaltyFee(uint96 _feeNumerator) external onlyOwner {
        royaltyFee = _feeNumerator;
        _setDefaultRoyalty(royaltyAddress, royaltyFee);
    }

    /**
     * @notice Change the royalty address where royalty payouts are sent
     */
    function setRoyaltyAddress(address _royaltyAddress) external onlyOwner {
        royaltyAddress = _royaltyAddress;
        _setDefaultRoyalty(royaltyAddress, royaltyFee);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    /**
     * @notice Allow owner to send tokens without cost to multiple addresses
     */
    function giftTokens(
        uint256 _tokenId,
        address[] calldata _receivers,
        uint256[] calldata _mintNumber
    ) external onlyOwner {
        require(
            !tokenMintingPermanentlyDisabled[_tokenId],
            "MINTING_PERMANENTLY_DISABLED"
        );
        uint256 totalMint = 0;
        for (uint256 i = 0; i < _mintNumber.length; i++) {
            totalMint += _mintNumber[i];
        }
        // require either no tokenMaxSupply set or tokenMaxSupply not maxed out
        require(
            tokenMaxSupply[_tokenId] == 0 ||
                totalSupply(_tokenId) + totalMint <= tokenMaxSupply[_tokenId],
            "MINT_TOO_LARGE"
        );
        for (uint256 i = 0; i < _receivers.length; i++) {
            _mint(_receivers[i], _tokenId, _mintNumber[i], "");
        }
    }

    /**
     * @notice To be updated by contract owner to allow public sale minting for a given token
     */
    function setTokenPublicSaleState(
        uint256 _tokenId,
        bool _saleActiveState
    ) external onlyOwner {
        require(
            tokenPublicSaleActive[_tokenId] != _saleActiveState,
            "NEW_STATE_IDENTICAL_TO_OLD_STATE"
        );
        tokenPublicSaleActive[_tokenId] = _saleActiveState;
    }

    /**
     * @notice Update the public mint price for a given token
     */
    function setTokenPublicPrice(
        uint256 _tokenId,
        uint256 _publicPrice
    ) external onlyOwner {
        tokenPublicPrice[_tokenId] = _publicPrice;
    }

    /**
     * @notice Set the maximum public mints allowed per a given address for a given token
     */
    function setTokenPublicMintsAllowedPerAddress(
        uint256 _tokenId,
        uint256 _mintsAllowed
    ) external onlyOwner {
        tokenPublicMintsPerAddress[_tokenId] = _mintsAllowed;
    }

    /**
     * @notice Update the start time for public mint for a given token
     */
    function setTokenPublicSaleStartTime(
        uint256 _tokenId,
        uint256 _publicSaleStartTime
    ) external onlyOwner {
        require(_publicSaleStartTime > block.timestamp, "TIME_IN_PAST");
        tokenPublicSaleStartTime[_tokenId] = _publicSaleStartTime;
    }

    /**
     * @notice Update the end time for public mint for a given token
     */
    function setTokenPublicSaleEndTime(
        uint256 _tokenId,
        uint256 _publicSaleEndTime
    ) external onlyOwner {
        require(_publicSaleEndTime > block.timestamp, "TIME_IN_PAST");
        tokenPublicSaleEndTime[_tokenId] = _publicSaleEndTime;
    }

    /**
     * @notice Update whether or not to use the automatic public sale times for a given token
     */
    function setTokenUsePublicSaleTimes(
        uint256 _tokenId,
        bool _usePublicSaleTimes
    ) external onlyOwner {
        require(
            tokenUsePublicSaleTimes[_tokenId] != _usePublicSaleTimes,
            "NEW_STATE_IDENTICAL_TO_OLD_STATE"
        );
        tokenUsePublicSaleTimes[_tokenId] = _usePublicSaleTimes;
    }

    /**
     * @notice Returns if public sale times are active for a given token
     */
    function tokenPublicSaleTimeIsActive(
        uint256 _tokenId
    ) public view returns (bool) {
        if (tokenUsePublicSaleTimes[_tokenId] == false) {
            return true;
        }
        return
            block.timestamp >= tokenPublicSaleStartTime[_tokenId] &&
            block.timestamp <= tokenPublicSaleEndTime[_tokenId];
    }

    /**
     * @notice Allow for public minting of tokens for a given token
     */
    function mintToken(
        uint256 _tokenId,
        uint256 _numTokens
    ) external payable originalUser nonReentrant {
        require(tokenPublicSaleActive[_tokenId], "PUBLIC_SALE_IS_NOT_ACTIVE");
        require(
            tokenPublicSaleTimeIsActive(_tokenId),
            "PUBLIC_SALE_TIME_IS_NOT_ACTIVE"
        );
        require(
            tokenPublicMintsPerAddress[_tokenId] == 0 ||
                tokensMintedByAddress[msg.sender][_tokenId] + _numTokens <=
                tokenPublicMintsPerAddress[_tokenId],
            "MAX_MINTS_FOR_ADDRESS_EXCEEDED"
        );
        require(
            tokenMaxSupply[_tokenId] == 0 ||
                totalSupply(_tokenId) + _numTokens <= tokenMaxSupply[_tokenId],
            "MAX_SUPPLY_EXCEEDED"
        );
        uint256 heymintFee = _numTokens * heymintFeePerToken;
        require(
            msg.value == tokenPublicPrice[_tokenId] * _numTokens + heymintFee,
            "PAYMENT_INCORRECT"
        );
        require(
            !tokenMintingPermanentlyDisabled[_tokenId],
            "MINTING_PERMANENTLY_DISABLED"
        );

        (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
        require(success, "Transfer failed.");
        tokensMintedByAddress[msg.sender][_tokenId] += _numTokens;
        _mint(msg.sender, _tokenId, _numTokens, "");

        if (
            tokenMaxSupply[_tokenId] != 0 &&
            totalSupply(_tokenId) >= tokenMaxSupply[_tokenId]
        ) {
            tokenPublicSaleActive[_tokenId] = false;
        }
    }

    /**
     * @notice Mint using a credit card
     */
    function creditCardMint(
        uint256 _tokenId,
        uint256 _numTokens,
        address _to
    ) external payable originalUser nonReentrant {
        bool authorized = false;
        for (uint256 i = 0; i < paperAddresses.length; i++) {
            if (msg.sender == paperAddresses[i]) {
                authorized = true;
                break;
            }
        }
        require(authorized, "NOT_AUTHORIZED_ADDRESS");

        require(tokenPublicSaleActive[_tokenId], "PUBLIC_SALE_IS_NOT_ACTIVE");
        require(
            tokenPublicSaleTimeIsActive(_tokenId),
            "PUBLIC_SALE_TIME_IS_NOT_ACTIVE"
        );
        require(
            tokenPublicMintsPerAddress[_tokenId] == 0 ||
                tokensMintedByAddress[_to][_tokenId] + _numTokens <=
                tokenPublicMintsPerAddress[_tokenId],
            "MAX_MINTS_FOR_ADDRESS_EXCEEDED"
        );
        require(
            tokenMaxSupply[_tokenId] == 0 ||
                totalSupply(_tokenId) + _numTokens <= tokenMaxSupply[_tokenId],
            "MAX_SUPPLY_EXCEEDED"
        );

        uint256 heymintFee = _numTokens * heymintFeePerToken;
        require(
            msg.value == tokenPublicPrice[_tokenId] * _numTokens + heymintFee,
            "PAYMENT_INCORRECT"
        );
        require(
            !tokenMintingPermanentlyDisabled[_tokenId],
            "MINTING_PERMANENTLY_DISABLED"
        );

        (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
        require(success, "Transfer failed.");
        tokensMintedByAddress[_to][_tokenId] += _numTokens;
        _mint(_to, _tokenId, _numTokens, "");

        if (
            tokenMaxSupply[_tokenId] != 0 &&
            totalSupply(_tokenId) >= tokenMaxSupply[_tokenId]
        ) {
            tokenPublicSaleActive[_tokenId] = false;
        }
    }

    /**
     * @notice Set the signer address used to verify presale minting
     */
    function setPresaleSignerAddress(
        address _presaleSignerAddress
    ) external onlyOwner {
        require(_presaleSignerAddress != address(0));
        presaleSignerAddress = _presaleSignerAddress;
    }

    /**
     * @notice To be updated by contract owner to allow presale minting for a given token
     */
    function setTokenPresaleState(
        uint256 _tokenId,
        bool _saleActiveState
    ) external onlyOwner {
        require(
            tokenPresaleSaleActive[_tokenId] != _saleActiveState,
            "NEW_STATE_IDENTICAL_TO_OLD_STATE"
        );
        tokenPresaleSaleActive[_tokenId] = _saleActiveState;
    }

    /**
     * @notice Update the presale mint price for a given token
     */
    function setTokenPresalePrice(
        uint256 _tokenId,
        uint256 _presalePrice
    ) external onlyOwner {
        tokenPresalePrice[_tokenId] = _presalePrice;
    }

    /**
     * @notice Set the maximum presale mints allowed per a given address for a given token
     */
    function setTokenPresaleMintsAllowedPerAddress(
        uint256 _tokenId,
        uint256 _mintsAllowed
    ) external onlyOwner {
        tokenPresaleMintsPerAddress[_tokenId] = _mintsAllowed;
    }

    /**
     * @notice Reduce the presale max supply of tokens for a given token id
     * @param _newPresaleMaxSupply The new maximum supply of tokens available to mint
     * @param _tokenId The token id to reduce the max supply for
     */
    function reducePresaleMaxSupply(
        uint256 _tokenId,
        uint256 _newPresaleMaxSupply
    ) external onlyOwner {
        require(
            tokenPresaleMaxSupply[_tokenId] == 0 ||
                _newPresaleMaxSupply < tokenPresaleMaxSupply[_tokenId],
            "NEW_MAX_SUPPLY_TOO_HIGH"
        );
        tokenPresaleMaxSupply[_tokenId] = _newPresaleMaxSupply;
    }

    /**
     * @notice Update the start time for presale mint for a given token
     */
    function setTokenPresaleStartTime(
        uint256 _tokenId,
        uint256 _presaleStartTime
    ) external onlyOwner {
        require(_presaleStartTime > block.timestamp, "TIME_IN_PAST");
        tokenPresaleSaleStartTime[_tokenId] = _presaleStartTime;
    }

    /**
     * @notice Update the end time for presale mint for a given token
     */
    function setTokenPresaleEndTime(
        uint256 _tokenId,
        uint256 _presaleEndTime
    ) external onlyOwner {
        require(_presaleEndTime > block.timestamp, "TIME_IN_PAST");
        tokenPresaleSaleEndTime[_tokenId] = _presaleEndTime;
    }

    /**
     * @notice Update whether or not to use the automatic presale times for a given token
     */
    function setTokenUsePresaleTimes(
        uint256 _tokenId,
        bool _usePresaleTimes
    ) external onlyOwner {
        require(
            tokenUsePresaleTimes[_tokenId] != _usePresaleTimes,
            "NEW_STATE_IDENTICAL_TO_OLD_STATE"
        );
        tokenUsePresaleTimes[_tokenId] = _usePresaleTimes;
    }

    /**
     * @notice Returns if presale times are active for a given token
     */
    function tokenPresaleTimeIsActive(
        uint256 _tokenId
    ) public view returns (bool) {
        if (tokenUsePresaleTimes[_tokenId] == false) {
            return true;
        }
        return
            block.timestamp >= tokenPresaleSaleStartTime[_tokenId] &&
            block.timestamp <= tokenPresaleSaleEndTime[_tokenId];
    }

    /**
     * @notice Verify that a signed message is validly signed by the presaleSignerAddress
     */
    function verifySignerAddress(
        bytes32 _messageHash,
        bytes calldata _signature
    ) private view returns (bool) {
        return
            presaleSignerAddress ==
            _messageHash.toEthSignedMessageHash().recover(_signature);
    }

    /**
     * @notice Allow for allowlist minting of tokens
     */
    function presaleMint(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _tokenId,
        uint256 _numTokens,
        uint256 _maximumAllowedMints
    ) external payable originalUser nonReentrant {
        require(tokenPresaleSaleActive[_tokenId], "PRESALE_IS_NOT_ACTIVE");
        require(
            tokenPresaleTimeIsActive(_tokenId),
            "PRESALE_TIME_IS_NOT_ACTIVE"
        );
        require(
            !tokenMintingPermanentlyDisabled[_tokenId],
            "MINTING_PERMANENTLY_DISABLED"
        );
        require(
            tokenPresaleMintsPerAddress[_tokenId] == 0 ||
                tokensMintedByAddress[msg.sender][_tokenId] + _numTokens <=
                tokenPresaleMintsPerAddress[_tokenId],
            "MAX_MINTS_PER_ADDRESS_EXCEEDED"
        );
        require(
            _maximumAllowedMints == 0 ||
                tokensMintedByAddress[msg.sender][_tokenId] + _numTokens <=
                _maximumAllowedMints,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            tokenPresaleMaxSupply[_tokenId] == 0 ||
                totalSupply(_tokenId) + _numTokens <=
                tokenPresaleMaxSupply[_tokenId],
            "MAX_SUPPLY_EXCEEDED"
        );
        uint256 heymintFee = _numTokens * heymintFeePerToken;
        require(
            msg.value == tokenPresalePrice[_tokenId] * _numTokens + heymintFee,
            "PAYMENT_INCORRECT"
        );
        require(
            keccak256(abi.encode(msg.sender, _maximumAllowedMints, _tokenId)) ==
                _messageHash,
            "MESSAGE_INVALID"
        );
        require(
            verifySignerAddress(_messageHash, _signature),
            "SIGNATURE_VALIDATION_FAILED"
        );

        (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
        require(success, "Transfer failed.");
        tokensMintedByAddress[msg.sender][_tokenId] += _numTokens;
        _mint(msg.sender, _tokenId, _numTokens, "");

        if (
            tokenPresaleMaxSupply[_tokenId] != 0 &&
            totalSupply(_tokenId) >= tokenPresaleMaxSupply[_tokenId]
        ) {
            tokenPresaleSaleActive[_tokenId] = false;
        }
    }

    /**
     * @notice Freeze all payout addresses and percentages so they can never be changed again
     */
    function freezePayoutAddresses() external onlyOwner {
        require(!payoutAddressesFrozen, "PAYOUT_ADDRESSES_ALREADY_FROZEN");
        payoutAddressesFrozen = true;
    }

    /**
     * @notice Update payout addresses and basis points for each addresses' respective share of contract funds
     */
    function updatePayoutAddressesAndBasisPoints(
        address[] calldata _payoutAddresses,
        uint256[] calldata _payoutBasisPoints
    ) external onlyOwner {
        require(!payoutAddressesFrozen, "PAYOUT_ADDRESSES_FROZEN");
        require(
            _payoutAddresses.length == _payoutBasisPoints.length,
            "ARRAY_LENGTHS_MUST_MATCH"
        );
        uint256 totalBasisPoints = 0;
        for (uint i = 0; i < _payoutBasisPoints.length; i++) {
            totalBasisPoints += _payoutBasisPoints[i];
        }
        require(totalBasisPoints == 10000, "TOTAL_BASIS_POINTS_MUST_BE_10000");
        payoutAddresses = _payoutAddresses;
        payoutBasisPoints = _payoutBasisPoints;
    }

    /**
     * @notice Withdraws all funds held within contract
     */
    function withdraw() external onlyOwner nonReentrant {
        require(address(this).balance > 0, "CONTRACT_HAS_NO_BALANCE");
        require(payoutAddresses.length > 0, "NO_PAYOUT_ADDRESSES");
        uint256 balance = address(this).balance;
        for (uint i = 0; i < payoutAddresses.length; i++) {
            uint256 amount = (balance * payoutBasisPoints[i]) / 10000;
            (bool success, ) = payoutAddresses[i].call{value: amount}("");
            require(success, "Transfer failed.");
        }
    }

    /**
     * @notice Override default ERC-1155 setApprovalForAll to require that the operator is not from a blocklisted exchange
     * @param operator Address to add to the set of authorized operators
     * @param approved True if the operator is approved, false to revoke approval
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @notice Override ERC1155 such that zero amount token transfers are disallowed.
     * This prevents arbitrary 'creation' of new tokens in the collection by anyone.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        require(amount > 0, "AMOUNT_CANNOT_BE_ZERO");
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function owner()
        public
        view
        virtual
        override(Ownable, UpdatableOperatorFilterer)
        returns (address)
    {
        return Ownable.owner();
    }
}


// File: @openzeppelin/contracts/utils/cryptography/ECDSA.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC1155/extensions/ERC1155Supply.sol)

pragma solidity ^0.8.0;

import "../ERC1155.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total supply per id.
 *
 * Useful for scenarios where Fungible and Non-fungible tokens have to be
 * clearly identified. Note: While a totalSupply of 1 might mean the
 * corresponding is an NFT, there is no guarantees that no other token with the
 * same id are not going to be minted.
 */
abstract contract ERC1155Supply is ERC1155 {
    mapping(uint256 => uint256) private _totalSupply;

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return ERC1155Supply.totalSupply(id) > 0;
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 amount = amounts[i];
                uint256 supply = _totalSupply[id];
                require(supply >= amount, "ERC1155: burn amount exceeds totalSupply");
                unchecked {
                    _totalSupply[id] = supply - amount;
                }
            }
        }
    }
}


// File: @openzeppelin/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File: @openzeppelin/contracts/security/Pausable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File: @openzeppelin/contracts/security/ReentrancyGuard.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File: @openzeppelin/contracts/token/common/ERC2981.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}


// File: operator-filter-registry/src/RevokableOperatorFilterer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {UpdatableOperatorFilterer} from "./UpdatableOperatorFilterer.sol";
import {IOperatorFilterRegistry} from "./IOperatorFilterRegistry.sol";

/**
 * @title  RevokableOperatorFilterer
 * @notice This contract is meant to allow contracts to permanently skip OperatorFilterRegistry checks if desired. The
 *         Registry itself has an "unregister" function, but if the contract is ownable, the owner can re-register at
 *         any point. As implemented, this abstract contract allows the contract owner to permanently skip the
 *         OperatorFilterRegistry checks by calling revokeOperatorFilterRegistry. Once done, the registry
 *         address cannot be further updated.
 *         Note that OpenSea will still disable creator fee enforcement if filtered operators begin fulfilling orders
 *         on-chain, eg, if the registry is revoked or bypassed.
 */
abstract contract RevokableOperatorFilterer is UpdatableOperatorFilterer {
    error RegistryHasBeenRevoked();
    error InitialRegistryAddressCannotBeZeroAddress();

    bool public isOperatorFilterRegistryRevoked;

    constructor(address _registry, address subscriptionOrRegistrantToCopy, bool subscribe)
        UpdatableOperatorFilterer(_registry, subscriptionOrRegistrantToCopy, subscribe)
    {
        // don't allow creating a contract with a permanently revoked registry
        if (_registry == address(0)) {
            revert InitialRegistryAddressCannotBeZeroAddress();
        }
    }

    function _checkFilterOperator(address operator) internal view virtual override {
        if (address(operatorFilterRegistry) != address(0)) {
            super._checkFilterOperator(operator);
        }
    }

    /**
     * @notice Update the address that the contract will make OperatorFilter checks against. When set to the zero
     *         address, checks will be permanently bypassed, and the address cannot be updated again. OnlyOwner.
     */
    function updateOperatorFilterRegistryAddress(address newRegistry) public override {
        if (msg.sender != owner()) {
            revert OnlyOwner();
        }
        // if registry has been revoked, do not allow further updates
        if (isOperatorFilterRegistryRevoked) {
            revert RegistryHasBeenRevoked();
        }

        operatorFilterRegistry = IOperatorFilterRegistry(newRegistry);
    }

    /**
     * @notice Revoke the OperatorFilterRegistry address, permanently bypassing checks. OnlyOwner.
     */
    function revokeOperatorFilterRegistry() public {
        if (msg.sender != owner()) {
            revert OnlyOwner();
        }
        // if registry has been revoked, do not allow further updates
        if (isOperatorFilterRegistryRevoked) {
            revert RegistryHasBeenRevoked();
        }

        // set to zero address to bypass checks
        operatorFilterRegistry = IOperatorFilterRegistry(address(0));
        isOperatorFilterRegistryRevoked = true;
    }
}


// File: @openzeppelin/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/ERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `ids` and `amounts` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// File: @openzeppelin/contracts/interfaces/IERC2981.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}


// File: @openzeppelin/contracts/utils/introspection/ERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File: @openzeppelin/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}


// File: operator-filter-registry/src/UpdatableOperatorFilterer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOperatorFilterRegistry} from "./IOperatorFilterRegistry.sol";

/**
 * @title  UpdatableOperatorFilterer
 * @notice Abstract contract whose constructor automatically registers and optionally subscribes to or copies another
 *         registrant's entries in the OperatorFilterRegistry. This contract allows the Owner to update the
 *         OperatorFilterRegistry address via updateOperatorFilterRegistryAddress, including to the zero address,
 *         which will bypass registry checks.
 *         Note that OpenSea will still disable creator fee enforcement if filtered operators begin fulfilling orders
 *         on-chain, eg, if the registry is revoked or bypassed.
 * @dev    This smart contract is meant to be inherited by token contracts so they can use the following:
 *         - `onlyAllowedOperator` modifier for `transferFrom` and `safeTransferFrom` methods.
 *         - `onlyAllowedOperatorApproval` modifier for `approve` and `setApprovalForAll` methods.
 */
abstract contract UpdatableOperatorFilterer {
    error OperatorNotAllowed(address operator);
    error OnlyOwner();

    IOperatorFilterRegistry public operatorFilterRegistry;

    constructor(address _registry, address subscriptionOrRegistrantToCopy, bool subscribe) {
        IOperatorFilterRegistry registry = IOperatorFilterRegistry(_registry);
        operatorFilterRegistry = registry;
        // If an inheriting token contract is deployed to a network without the registry deployed, the modifier
        // will not revert, but the contract will need to be registered with the registry once it is deployed in
        // order for the modifier to filter addresses.
        if (address(registry).code.length > 0) {
            if (subscribe) {
                registry.registerAndSubscribe(address(this), subscriptionOrRegistrantToCopy);
            } else {
                if (subscriptionOrRegistrantToCopy != address(0)) {
                    registry.registerAndCopyEntries(address(this), subscriptionOrRegistrantToCopy);
                } else {
                    registry.register(address(this));
                }
            }
        }
    }

    modifier onlyAllowedOperator(address from) virtual {
        // Allow spending tokens from addresses with balance
        // Note that this still allows listings and marketplaces with escrow to transfer tokens if transferred
        // from an EOA.
        if (from != msg.sender) {
            _checkFilterOperator(msg.sender);
        }
        _;
    }

    modifier onlyAllowedOperatorApproval(address operator) virtual {
        _checkFilterOperator(operator);
        _;
    }

    /**
     * @notice Update the address that the contract will make OperatorFilter checks against. When set to the zero
     *         address, checks will be bypassed. OnlyOwner.
     */
    function updateOperatorFilterRegistryAddress(address newRegistry) public virtual {
        if (msg.sender != owner()) {
            revert OnlyOwner();
        }
        operatorFilterRegistry = IOperatorFilterRegistry(newRegistry);
    }

    /**
     * @dev assume the contract has an owner, but leave specific Ownable implementation up to inheriting contract
     */
    function owner() public view virtual returns (address);

    function _checkFilterOperator(address operator) internal view virtual {
        IOperatorFilterRegistry registry = operatorFilterRegistry;
        // Check registry code length to facilitate testing in environments without a deployed registry.
        if (address(registry) != address(0) && address(registry).code.length > 0) {
            if (!registry.isOperatorAllowed(address(this), operator)) {
                revert OperatorNotAllowed(operator);
            }
        }
    }
}


// File: operator-filter-registry/src/IOperatorFilterRegistry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOperatorFilterRegistry {
    function isOperatorAllowed(address registrant, address operator) external view returns (bool);
    function register(address registrant) external;
    function registerAndSubscribe(address registrant, address subscription) external;
    function registerAndCopyEntries(address registrant, address registrantToCopy) external;
    function unregister(address addr) external;
    function updateOperator(address registrant, address operator, bool filtered) external;
    function updateOperators(address registrant, address[] calldata operators, bool filtered) external;
    function updateCodeHash(address registrant, bytes32 codehash, bool filtered) external;
    function updateCodeHashes(address registrant, bytes32[] calldata codeHashes, bool filtered) external;
    function subscribe(address registrant, address registrantToSubscribe) external;
    function unsubscribe(address registrant, bool copyExistingEntries) external;
    function subscriptionOf(address addr) external returns (address registrant);
    function subscribers(address registrant) external returns (address[] memory);
    function subscriberAt(address registrant, uint256 index) external returns (address);
    function copyEntriesOf(address registrant, address registrantToCopy) external;
    function isOperatorFiltered(address registrant, address operator) external returns (bool);
    function isCodeHashOfFiltered(address registrant, address operatorWithCode) external returns (bool);
    function isCodeHashFiltered(address registrant, bytes32 codeHash) external returns (bool);
    function filteredOperators(address addr) external returns (address[] memory);
    function filteredCodeHashes(address addr) external returns (bytes32[] memory);
    function filteredOperatorAt(address registrant, uint256 index) external returns (address);
    function filteredCodeHashAt(address registrant, uint256 index) external returns (bytes32);
    function isRegistered(address addr) external returns (bool);
    function codeHashOf(address addr) external returns (bytes32);
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


