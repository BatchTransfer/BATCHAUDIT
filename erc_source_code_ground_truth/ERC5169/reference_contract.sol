import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC5169.sol";
contract ERC5169 is IERC5169, Ownable {
    string[] private _scriptURI;
    function scriptURI() external view override returns(string[] memory) {
        return _scriptURI;
    }

    function setScriptURI(string[] memory newScriptURI) external onlyOwner override {
        _scriptURI = newScriptURI;

        emit ScriptUpdate(newScriptURI);
    }
}
