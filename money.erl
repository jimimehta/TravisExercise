%% @author Jimi Mehta 40225526

-module(money).
-import(customer,[createThreads/3]).
-import(bank,[createBanksThreads/2]).


-export([start/1]).

%%	Start()
start(Args) ->
	CustomerFile = lists:nth(1, Args),
	BankFile = lists:nth(2, Args),

	{ok, CustData} = file:consult(CustomerFile),
	{ok, BankData} = file:consult(BankFile),

	%%	Pid = self(),
	io:fwrite(" "),
	CustomerMaps = maps:from_list( CustData ),
	BanksMap = maps:from_list( BankData ),
	BankList = maps:keys( BanksMap ),
	CusList = maps:keys( CustomerMaps ),
	Blmap = BanksMap,
	Clmap = CustomerMaps,

	%% ====================================================================
	%%  To display Customer and Bank Data
	%%	io:fwrite("** Customers and Amount Data **~n"),
	%%	display(length(CustData),1,CustData),
	%%	io:fwrite("** Banks and Amount **~n"),
	%%	display(length(BankData),1,BankData),
	%% ====================================================================

	%% Start of Display
	io:fwrite("~n"),
	io:fwrite("** The financial market is opening for the day **~n~n"),
	io:fwrite("Starting transaction log...~n~n"),

	BankThreads = createBanksThreads(BankData,self()),
	createThreads(CustData,BankThreads,self()),

	{NBsM, NCsM}=master(CustData,BankData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads),

	%% NBsM, NCsM : Generated values of Remaining Bank Amount and Customer Amount
	%% io:fwrite("NBsM ~p ,NCsm ~p ~n", [NBsM, NCsM]),
	io:fwrite("~nTransaction log Ended~n"),

	TotalObj = lists:sum(maps:values(CustomerMaps)),
	TotalOri = lists:sum(maps:values(BanksMap)),

	io:fwrite("~n~n"),
	io:fwrite("** Banking Report **~n~n"),

	io:fwrite("Customer:~n"),
	io:fwrite("	----- ~n	Total: objective ~p, received ~p ~n", [TotalObj, cReport1(CusList,CustomerMaps,NCsM)]),	
	io:fwrite("~n"),

	io:fwrite("Banks:~n"),
	io:fwrite("	----- ~n	Total: original ~p, loaned ~p ~n", [TotalOri, cReport2(BankList,BanksMap,NBsM)]),
	io:fwrite("~n~n"),
	io:fwrite("The financial market is closing for the day...~n~n").

%% cReport1(CusList,CustomerMaps,NCsM ),
%% cReport2(BankList,BanksMap,NBsM ).


bloop([H|T], BanksMap) -> Pid = maps:get( H, BanksMap),
	Pid ! {displayBalance},
	%%io:fwrite("Shutting down ~p~n", [H]),
	bloop(T, BanksMap);
bloop([], _) -> ok.

cReport1([H|T], CRep, BRep) ->
	MR = maps:get(H, BRep),
	MO = maps:get(H, CRep)-MR,
	io:fwrite("	~p: objective ~p, received ~p ~n", [H, maps:get(H, CRep), MO]),
	Total=MO + cReport1(T, CRep, BRep),
	Total;
cReport1([],_,_ ) -> 0. 

cReport2([H|T], CRep, BRep) ->
	MR = maps:get(H, BRep),
	MO = maps:get(H, CRep) - MR,
	io:fwrite("	~p: original ~p, balance ~p ~n", [H, maps:get(H, CRep), maps:get(H, BRep)]),
	Total = MO + cReport2(T, CRep, BRep),
	Total;
cReport2([],_,_) -> 0.	


%%	Master Function to Print and Calculate loan Proceedings

%%	Base Case
%% master(CData,BData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads) when (length(BankList)==0) -> {Blmap,Clmap};
master(_,_,_,_,BankList,_,Blmap,Clmap,_) when (length(BankList)==0) -> {Blmap,Clmap};

%%	Normal Case
master(CData,BData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads) ->
	if 
		length(CusList)==0 ->
		%%i	o:fwrite("Pass ~n "),
		bloop(BankList,BankThreads);
		true ->
		ok
	end,

	receive
	{loanRequest, Customer,Amount,BankName} ->
		io:fwrite("?  ~p requests a loan of ~p dollar(s) from ~p bank~n",[Customer,Amount,BankName]),
		{NBsM, NCsM}=master(CData,BData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads),
		{NBsM, NCsM};

	{frombankApproved, BankName, Amount,Customer} ->
		io:fwrite("$  The ~p bank approves a loan of ~p dollar(s) to ~p~n",[BankName,Amount,Customer]),
		{NBsM, NCsM}=master(CData,BData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads),
		{NBsM, NCsM};

	{frombankDisApproved, BankName, Amount,Customer} ->
		io:fwrite("$  The ~p bank denies a loan of ~p dollar(s) to ~p~n",[BankName,Amount,Customer]),
		{NBsM, NCsM}=master(CData,BData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads),
		{NBsM, NCsM};

	{flag1, Customer,Amount}->
		NCusList = lists:delete( Customer, CusList),
		NClmap = maps:put(Customer, Amount, Clmap),
		{NBsM, NCsM}=master(CData,BData,CustomerMaps,BanksMap,BankList,NCusList,Blmap,NClmap,BankThreads),
		{NBsM, NCsM};

	{flag0, Customer,LoanAmount} ->
		NCusList = lists:delete( Customer, CusList),
		NClmap = maps:put(Customer, LoanAmount, Clmap),
		{NBsM, NCsM}=master(CData,BData,CustomerMaps,BanksMap,BankList,NCusList,Blmap,NClmap,BankThreads),
		{NBsM, NCsM};

	{myBalance,BankName, BankBalance} ->
		%%	io:fwrite("~p has ~p dollar(s) remaining.~n",[BankName,BankBalance]),
		NBankList = lists:delete(BankName, BankList),
		NBlmap = maps:put(BankName, BankBalance, Blmap),
		{NBsM, NCsM} = master(CData,BData,CustomerMaps,BanksMap,NBankList,CusList,NBlmap,Clmap,BankThreads),
		{NBsM, NCsM}
	end.

%%	Other ->
%%	io:fwrite(" "),
%%	{NBsM, NCsM}=master(CData,BData,CustomerMaps,BanksMap,BankList,CusList,Blmap,Clmap,BankThreads),
%%	{NBsM, NCsM}