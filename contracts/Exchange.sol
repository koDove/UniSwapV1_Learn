//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

import "./interfaces/IFactory.sol";
import "./interfaces/IExchange.sol";

contract Exchange is ERC20 {
    IERC20 token;
    IFactory factory;

    constructor(address _token) ERC20("DOVE LP TOKEN", "DOLP") {
        //토큰의 주소를 인자로 받는다.
        token = IERC20(_token);
        factory = IFactory(msg.sender);
    }

    //CSMM(Contract Sum Market Maker)은 x+y=k 공식을 따른다(x,y는 유동성 풀에 들어있는 토큰의 개수이다).
    //슬리피지가 없으며, 풀의 유동성이 0이 될 수 있다.
    //때문에 정말 간단한 수식으로만 구현되기 때문에 독자적으로 사용하지 않는다.
    //스왑 시 내가 넣은 input과 받는 output 토큰의 개수가 같다.
    //예를 들어 각 풀이 1000개씩을 가지고 있고, 1ETH를 GRAY로 스왑할 경우의 토큰 비율은 1ETH = 999/1001 GRAY가 된다.

    /*function addLiquidity(uint256 _tokenAmount) public payable {//유동성 공급 V1
        token.transferFrom(msg.sender, address(this), _tokenAmount);
    }*/

    function addLiquidity(uint256 _maxTokens) public payable {
        //유동성 공급 V2 (LP Token 발급 추가버전)
        uint256 totalLiquidity = totalSupply();
        if (totalLiquidity > 0) {
            //기존 유동성 풀에 유동성이 존재하는 경우
            //UniSwap과 같이 ETH를 기준으로 한다.
            uint256 ethReserve = address(this).balance - msg.value; //현재 ETH풀의 잔액
            uint256 tokenReserve = token.balanceOf(address(this)); //현재 토큰풀의 잔액
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve; // 공급할 유동성의 양
            require(_maxTokens >= tokenAmount); //슬리피지 확인
            token.transferFrom(msg.sender, address(this), tokenAmount); //유동성 공급

            uint256 liquidityMinted = (totalLiquidity * msg.value) / ethReserve; // 발행해줄 LP토큰 계산
            _mint(msg.sender, liquidityMinted); //LP토큰 발행해줌
        } else {
            //기존 풀에 유동성이 없는 경우
            uint256 tokenAmount = _maxTokens;
            uint256 initialLiquidity = address(this).balance;
            _mint(msg.sender, initialLiquidity);
            token.transferFrom(msg.sender, address(this), tokenAmount);
        }
        console.log(
            "addLiquidity Result Amount / ETH :",
            address(this).balance,
            " GRAY :",
            token.balanceOf(address(this))
        );
    } //CSMM 공식에 따라 유동성을 추가한다. _tokenAmount에 따라 유동성을 허용할 금액을 설정한다.

    //사전에 approve과정이 선행돼야 하며, ETH코인은 포로토콜 레벨에서 전송된다.(예: {value: 1000})
    //transfer가 아닌 transferFrom인 이유는 내가 token컨트렉트를 호출하는게 아니라 Exchange로 하여금 token컨트랙트와 내 자금을 가지고 상호작용하도록 만들기 위해서 내 자금의 권한을 Exchange권한을 넘겨(approve)주고 권한을 인계받아 처리(transferFrom)해야 하는 것이다.

    function removeLiquidity(uint256 _lpTokenAmount) public {
        //사용자가 반납하는 LP토큰을 인자로 받음
        //분명 사용자가 LP토큰을 제대로 소유하고 있는지 확인절차가 있을것이라 예상
        uint256 totalLiquidity = totalSupply(); //현재 유동성 토큰 풀의 잔액
        uint256 ethAmount = (_lpTokenAmount * address(this).balance) /
            totalLiquidity; //돌려받을 ETH 개수
        uint256 tokenAmount = (_lpTokenAmount *
            token.balanceOf(address(this))) / totalLiquidity;

        _burn(msg.sender, _lpTokenAmount); //반납한 LP토큰 소각

        payable(msg.sender).transfer(ethAmount); //지불한 LP토큰만큼 ETH 돌려줌
        token.transfer(msg.sender, tokenAmount); //지불한 LP토큰만큼의 토큰을 돌려줌
        console.log(
            "removeLiquidity Result Amount / ETH :",
            address(this).balance,
            " GRAY :",
            token.balanceOf(address(this))
        );
    }

    /*function removeLiquidity(){
        //검증로직 추가
        msg.sender.tranfer(ethAmount);
        token.transfer(msg.sender, tokenAmount);
    }*/

    /*function ethToTokenSwap() public payable {
        uint256 inputAmount = msg.value;
        uint256 outputAmount = inputAmount; //CSMM공식에 따라 output토큰은 input이더리움의 개수와 같다.
        token.transfer(msg.sender, outputAmount);
    }*/

    function getPrice(
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 numerator = inputReserve;
        uint256 denominator = outputReserve;
        return numerator / denominator;
    }

    //CPMM은 xy=k 공식을 따른다.
    //CPMM은 Slippage가 존재한다. 이는 예상한 스왑 토큰과 실제 계산돼서 받은 토큰이 다를 수 있다는 뜻이다. 덕분에 유동성 풀이 고갈되지 않는다.
    //CSMM은 반드시 1대1로 교환하기 때문에 간단하지만 CPMM은 공식에 따라 토큰을 반환한다.
    function getOutputAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 numerator = (inputAmount * outputReserve);
        uint256 denominator = (inputAmount + inputReserve);
        return numerator / denominator;
    } //실제로 eth를 전송하면 받게된 스왑 토큰의 개수를 반환한다.

    function getOutputAmountWithFee(
        //스왑 계산, 수수료 구현 버전(1퍼센트의 수수료)
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = (inputAmountWithFee * outputReserve);
        uint256 denominator = (inputAmountWithFee + inputReserve * 100);
        return numerator / denominator;
    }

    function tokenBalance() public view returns (uint256) {
        console.log("GRAY POOL Amount :", token.balanceOf(address(this)));
        return token.balanceOf(address(this));
    }

    function ethToTokenSwap(uint _minTokens) public payable {
        ethToToken(_minTokens, msg.sender);
    }

    function ethToTokenTransfer(
        uint256 _minTokens,
        address _recipient
    ) public payable {
        ethToToken(_minTokens, _recipient);
    }

    function ethToToken(uint _minTokens, address _recipient) private {
        uint256 tokenReserve = token.balanceOf(address(this)); //토큰 풀에 존재하는 잔액 조회
        uint256 outputAmount = getOutputAmountWithFee(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );
        // inputReserve에서 ETH를 빼주는 이유는 사용자가 트랜잭션에 ETH를 담아 전송함으로써 풀에 해당 ETH가 선행 반영됐기 때문.
        //console.log("ethtokenSwap Result : ", outputAmount);
        require(outputAmount >= _minTokens, "Insufficient output Amount");
        //_minTokens는 사용자가 최소한 이정도는 받아야한다고 지정한 값이다. 이 값이 실제 스왑해서 받게될 토큰보다 커야한다.
        //_minTokens는 프론트엔드로부터 계산된 값이 전해져온다.
        require(token.transfer(_recipient, outputAmount));
    }

    function tokenToEthSwap(
        uint256 _tokenSold,
        uint256 _minEth
    ) public payable {
        uint outputAmount = getOutputAmountWithFee(
            _tokenSold,
            token.balanceOf(address(this)),
            address(this).balance
        );

        require(outputAmount >= _minEth, "Insufficient output Amount");

        token.transfer(msg.sender, outputAmount);
        payable(msg.sender).transfer(outputAmount);
    }

    //UniSwap에는 Swap말고 Send라는 기능도 있다. 이는 Swap하고 특정 주소로 보내는 기능을 합친 기능이다.

    function tokenToTokenSwap(
        uint256 _tokenSold,
        uint256 _minTokenBought,
        uint256 _minEthBought,
        address _tokenAddress
    ) public payable {
        //minEthBought: 중간 과정에서 스왑돼서 획득할 이더 양의 최소치를 지정.

        address toTokenExchangeAddress = factory.getExchange(_tokenAddress);

        uint ethOutputAmount = getOutputAmountWithFee(
            _tokenSold,
            token.balanceOf(address(this)),
            address(this).balance
        );

        require(ethOutputAmount >= _minEthBought, "Insufficient output Amount");

        token.transferFrom(msg.sender, address(this), _tokenSold);
        //==1번째 스왑 끝

        //==2번째 스왑 시작
        //새로운 인터페이스를 구축하고 그걸 통해서 스왑을 진행해야함.
        IExchange(toTokenExchangeAddress).ethToTokenTransfer{
            value: ethOutputAmount
        }(_minTokenBought, msg.sender);
    }
}
