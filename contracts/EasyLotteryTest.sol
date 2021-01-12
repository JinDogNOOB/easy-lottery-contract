// SPDX-License-Identifier: WTFPL
pragma solidity >=0.7.0 <0.9.0;




contract EasyLotteryTest{
    address payable OWNER;
    // 로또 회차(블록넘버)
    uint256 public GAME_NUMBER;
    // 모인 돈
    uint256 public DEV_WEI;
    uint256 public GATHERED_WEI;
    // 로또 한 회의 시작 블록 넘버
    // 시작 + 36864(6일) == 복권구매금지 시작시간
    // 복권구매금지 시작시간 + 25 == 복권당첨번호 기준 블록
    // 복권당첨번호 기준 블록 + 25 == 정산메소드 동작가능시간 시작
    // 
    // 복권당첨번호 기준 블록 으로부터 200블록 지났으면 이월
    uint256 public START_BLOCK_NUMBER;
    // 5일 36864
    uint256 public PURCHASE_PERIOD = 25;
    mapping(uint256 => mapping(uint8 => address payable[])) public PARTICIPANTS;
    
    
    // constructor
    constructor(){
        OWNER = payable(msg.sender);
        GAME_NUMBER = 0;
        GATHERED_WEI = 0;
        DEV_WEI = 0;
        START_BLOCK_NUMBER = block.number+1;
    }

    modifier onlyOwner{
        require(msg.sender == OWNER, "only owner can call the function");
        _;
    }

    function destroy() public onlyOwner{
        selfdestruct(OWNER);
    }


    /**
    external 
    로또 참여 함수
    number : 1~100
    msg.value 0.0015ETH 이상
    */
    function passNumberNPay(uint8 number) external payable returns(bool){
        require(0 < number && number < 101, "number should be within 1~100");
        require(msg.value >= 1500000000000000, "msg.value must be higher than 0.0015ETH");
        require(START_BLOCK_NUMBER+PURCHASE_PERIOD > block.number, "can't do this after startBlockNumber+PURCHASE_PERIOD");

        PARTICIPANTS[GAME_NUMBER][number].push(payable(msg.sender));
        GATHERED_WEI += msg.value;
        return true;
    }

    // 아 이더리움 dirty read 같은거 조사좀 해봐야하는데
    // 만약 dirty read 같은거를 evm이 막으면 onlyOwner로 굳이 주인이 draw안호출해도된다
    // 전부한테 풀어버리고 맨 처음 한 사람이 draw() 하고 인센티브 조금 가져가고 아 이거는 생각해봐야한다.. 굳이?
    function draw() external payable returns(bool){
        require(START_BLOCK_NUMBER+PURCHASE_PERIOD+50 <= block.number, "you can draw lottery only after startBlockNumber+PURCHASE_PERIOD+50");

        bool result = false;
        if(START_BLOCK_NUMBER+PURCHASE_PERIOD+50+175 < block.number){
            // 기한 넘음 => 돈 이월하고(그대로 두고) 새 게임 시작
            startNewGame();
        }else if(PARTICIPANTS[GAME_NUMBER][getWinningNumber()].length == 0){
            // 당첨자 없음 => 돈 이월하고 새 게임 시작
            startNewGame();
        }else{
            // 당첨자 존재 => 당첨자에게 송금
            sendETHtoWinners(payable(msg.sender));
            GATHERED_WEI = 0; // 모인액수 초기화
            startNewGame();
            result = true;
        }
        return result;
    }

    function sendWeiToDev() onlyOwner external{
        OWNER.transfer(DEV_WEI);
        DEV_WEI = 0;
    }

    
    // #### PRIVATE METHODS ####

    // startNewGame
    function startNewGame() private {
        GAME_NUMBER++;
        START_BLOCK_NUMBER = block.number+1;
    }

    // get winningNumber
    function getWinningNumber() private view returns (uint8){
        bytes32 hashval = blockhash(START_BLOCK_NUMBER+PURCHASE_PERIOD+25);
        bytes1 result = hashval[0];
        for(uint8 i = 1; i < hashval.length; i++){
            result ^= hashval[i];
        }
        return uint8(result) % 100 + 1 ;
    }

    // sendETHtoWinners
    function sendETHtoWinners(address payable caller) private{
        uint256 gatheredWeiToWinner = (GATHERED_WEI / 1000)*997; // 전체 금액의 99.7퍼센트를 당첨자에게 & 0.29% -> caller & 0.01% -> developer
        uint256 gatheredWeiToCaller = (GATHERED_WEI / 10000)*29;
        uint256 gatheredWeiToDev = (GATHERED_WEI / 10000)*1;
        uint8 winningNumber = getWinningNumber();
        uint numberOfWinners = PARTICIPANTS[GAME_NUMBER][winningNumber].length;
        // 전송
        for(uint i = 0; i < numberOfWinners; i++){
            PARTICIPANTS[GAME_NUMBER][winningNumber][i].transfer(gatheredWeiToWinner/numberOfWinners);
        }
        caller.transfer(gatheredWeiToCaller);
        DEV_WEI += gatheredWeiToDev;
    }
}