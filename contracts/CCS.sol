// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWormhole.sol";

contract CrossChainSwap is ERC20, ERC20Burnable, Ownable {

    constructor() ERC20("Castling Deposit", "CAST") {
    }

    uint32 nonce = 0;
    address constant base_token = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa; //polygon mumbai (WETH)

    uint24 cutOffRatio = 500;
    uint24 baseFee = 50;

    function setbaseFee (uint24 _baseFee) public onlyOwner {
        baseFee = _baseFee;
    }

    function getbaseFee() public view returns (uint24) {
        return baseFee;
    }

    function setcutOffRatio (uint24 _baseFee) public onlyOwner {
        baseFee = _baseFee;
    }

    function getcutOffRatio() public view returns (uint24) {
        return baseFee;
    }

    function calculateFinalAmount(uint256 amount, uint256 baseBalance, uint256 destBalance) public view returns(uint256) {
        
        uint256 RealRatio = (baseBalance * 1000) / (destBalance + baseBalance);
        
        if(RealRatio > (cutOffRatio / 2)){
            return amount - ((amount *  baseFee * (((2000 * RealRatio) / cutOffRatio) - 1000)) / 1e8);
        }

        return amount + ((amount *  baseFee * (1000 - ((2000 * RealRatio) / cutOffRatio))) / 1e8);

    }

    address a = address(0x0CBE91CF822c73C2315FB05100C2F714765d5c20);
    IWormhole _wormhole = IWormhole(a);

    
    ISwapRouter constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function CCSwapStart (address tokenIn, address tokenOut, uint24 poolFee, uint amountIn) public returns (uint64 sequence){
            
            uint256 amountOut = swapIn(tokenIn, base_token, poolFee, amountIn);
            sequence = send_to_destination(msg.sender, tokenOut, amountOut, IERC20(base_token).balanceOf(address(this)));
        
        }

    function swapIn(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint amountIn
    ) public returns (uint amountOut) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = router.exactInputSingle(params);
    }

    function swapOut(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint amountIn,
        address recipient
    ) public returns (uint amountOut) {

        IERC20(tokenIn).approve(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: recipient,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = router.exactInputSingle(params);
    }

    function mint_for_deposit(uint amount) public {
        require((IERC20(base_token).allowance(msg.sender, address(this))>=amount));  
        require(IERC20(base_token).transferFrom(msg.sender, address(this), amount));
        _mint(msg.sender, amount);
    }

    function burn_for_withdrawal(uint amount) public {
        require((IERC20(address(this)).balanceOf(msg.sender)>=amount));  
        require((IERC20(base_token).balanceOf(address(this))>=amount));
        require(IERC20(base_token).transfer(msg.sender, amount));
        _burn(msg.sender, amount);
    }

    function send_to_destination(address sender, address destinationToken, uint256 amount, uint256 baseBalance) internal returns (uint64 sequence) {
        sequence = _wormhole.publishMessage(nonce, abi.encode(sender, amount, destinationToken, baseBalance), 200);
        nonce = nonce + 1;
        return sequence;
    }

    function CCSwapEnd(bytes calldata encodedVM, uint24 poolFee) public returns (uint256 amountRecieved) {
        
        IWormhole.VM memory vm = _wormhole.parseVM(encodedVM);
        
        (address sender, uint256 amount,address destinationToken, uint256 baseBalance) = abi.decode(vm.payload, (address, uint256, address, uint256));

        uint256 baseAmountSwap = calculateFinalAmount(amount, baseBalance, IERC20(base_token).balanceOf(address(this)));

        amountRecieved = swapOut(base_token, destinationToken, poolFee, baseAmountSwap, sender);

    }
    function wormhole() public view returns (IWormhole) {
        return _wormhole;
    }
}