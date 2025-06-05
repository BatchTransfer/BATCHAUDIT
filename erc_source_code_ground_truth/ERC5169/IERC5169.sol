interface IERC5169 {
    /// @dev This event emits when the scriptURI is updated, 
    /// so wallets implementing this interface can update a cached script
    event ScriptUpdate(string[] newScriptURI);

    /// @notice Get the scriptURI for the contract
    /// @return The scriptURI
    function scriptURI() external view returns(string[] memory);

    /// @notice Update the scriptURI 
    /// emits event ScriptUpdate(scriptURI memory newScriptURI);
    function setScriptURI(string[] memory newScriptURI) external;
}