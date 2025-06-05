/**
 * @title Semantic Soulbound Token
 * Note: the ERC-165 identifier for this interface is 0xfbafb698
 */
interface ISemanticSBT{
    /**
     * @dev This emits when minting a Semantic Soulbound Token.
     * @param tokenId The identifier for the Semantic Soulbound Token.
     * @param rdfStatements The RDF statements for the Semantic Soulbound Token. 
     */
    event CreateRDF (
        uint256 indexed tokenId,
        string  rdfStatements
    );
    /**
     * @dev This emits when updating the RDF data of Semantic Soulbound Token. RDF data is a collection of RDF statements that are used to represent information about resources.
     * @param tokenId The identifier for the Semantic Soulbound Token.
     * @param rdfStatements The RDF statements for the semantic soulbound token. 
     */
    event UpdateRDF (
        uint256 indexed tokenId,
        string  rdfStatements
    );
    /**
     * @dev This emits when burning or revoking Semantic Soulbound Token.
     * @param tokenId The identifier for the Semantic Soulbound Token.
     * @param rdfStatements The RDF statements for the Semantic Soulbound Token. 
     */
    event RemoveRDF (
        uint256 indexed tokenId,
        string  rdfStatements
    );
    /**
     * @dev Returns the RDF statements of the Semantic Soulbound Token. 
     * @param tokenId The identifier for the Semantic Soulbound Token.
     * @return rdfStatements The RDF statements for the Semantic Soulbound Token. 
     */
    function rdfOf(uint256 tokenId) external view returns (string memory rdfStatements);
}