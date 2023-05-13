# UniSwapV1_Learn
UniswapV1_CloneCoding(solidity) With comment




## Factory 기능을 이해하기 위한 여정
3가지 요소가 있다.

- Factory: 서로 다른 Exchange 컨트랙트 주소를 모아둔 것이다. 이름하야 주소록.
예를 들어 ETH-Dove, ETH-VID, ETH-XXA 스왑 풀들이 존재할 때 이들은 모두 각자의 Exchange 컨트랙트에 의해 관리될 것이다. 때문에 이들을 하나로 모아주는게 Factory다.
- **Exchange: Eth-Token 혹은 Token-Token간의 스왑을 정의한다.**
이 과정에서는 가격 측정, 유동성 공급, 스왑, LP토큰 발행, 수수료 처리 등을 다룬다.
생성 인자로 Token Contract의 주소를 받는다.
- **Token: 하나의 토큰을 정의한다.**

그럼 토큰-토큰 스왑의 실제 구현은 어떻게??

이것은 인터페이스를 활용한다.

작동순서

1. 토큰을 발행한 후 Factory의 createExchange에 토큰 주소를 전달한다.
2. createExchange는 받은 토큰 주소로 Exchange 컨트랜트를 생성해서 ETH-토큰 풀을 만든다. 이때 Exchange 컨트랙트의 주인은 Factory CA가 된다(관리하기 위함).
+ Exchange 생성시 msg.sender(factory)로 Factory에 대한 인터페이스를 설정해놔야 Exchange에서 특정 다른 Token에 대응하는 토큰 풀(Exchange) 주소를 가져올 수 있다. 이걸 안하면 Factory 주소를 하드코딩 해야함.
3. A토큰-B토큰 교환을 실시한다. 물론 바로는 안되고 A토큰-ETH 스왑 → ETH-B토큰 스왑 식으로 진행해야 한다.
4. A-토큰-ETH는 기존에 하던것 처럼 하면 된다. 다만 사용자에게 돌려줄 ETH를 factory를 통해 받아온 B토큰 풀(Exchange)의 주소로 인터페이스(IExchange)를 활용해서 ETH-B토큰 스왑을 실시한다.
5. ETH-B토큰 교환시에는 반드시 토큰-토큰을 스왑한 EOA의 주소를 같이 전달해줘야 스왑된 B토큰의 수신자를 올바르게 지정할 수 있다. 이제 EOA주소를 전달해서 ETH-B토큰 스왑을 진행하면 A토큰-B토큰 스왑이 완료된다.
