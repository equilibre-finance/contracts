// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVoter {
    function _ve() external view returns (address);
    function governor() external view returns (address);
    function emergencyCouncil() external view returns (address);
    function attachTokenToGauge(uint _tokenId, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distribute(address _gauge) external;
    function claimFees(address[] memory _fees, address[][] memory _tokens, uint _tokenId) external;
    function gauges(address _gauge) external view returns (address);
    function internal_bribes(address _gauge) external view returns (address);
    function external_bribes(address _gauge) external view returns (address);
    function length() external view returns (uint);
    function pools(uint _index) external view returns (address);
    function isAlive(address _gauge) external view returns (bool);
}
