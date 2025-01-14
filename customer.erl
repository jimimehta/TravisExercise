%% @author Jimi Mehta 40225526

-module(customer).

-export([createThreads/3,toCreateThreads/6,loanReq/5,toInitiateThreads/5,applyLoan/6]).


toCreateThreads(Max,Min,_,TempMap,_,_) when Min > Max -> TempMap;
toCreateThreads(Max,Min,Data,TempMap,MasterPid,BanksMap) when Min =< Max ->
	Row = lists:nth(Min,Data),
	Customer = element(1,Row),
	Amount = element(2,Row),
	Pid = spawn(customer,loanReq,[Customer,Amount, Amount,MasterPid,BanksMap]),
	%% 	MasterPid ! {message,"Received"},
	UpdatedMap = maps:put(Customer,Pid,TempMap),
toCreateThreads(Max,Min+1,Data,UpdatedMap,MasterPid,BanksMap).


applyLoan(Customer,Amount,BanksMap,KeySet,CustomerPid,MasterPid)->
	Index = rand:uniform(length(KeySet)),
	BankName = lists:nth(Index,KeySet),
	Pid = maps:get(BankName, BanksMap),
	RequestAmount = rand:uniform(50),
	SleepTime = rand:uniform(100-10)+10,
	timer:sleep(SleepTime),
	if
		RequestAmount =< Amount ->
		Pid ! {request,Customer,RequestAmount,CustomerPid},
		MasterPid ! {loanRequest, Customer,RequestAmount,BankName};
		RequestAmount > Amount ->
		Pid ! {request,Customer,Amount,CustomerPid},
		MasterPid ! {loanRequest, Customer,Amount,BankName}
	end.


toInitiateThreads(Max,Min,_,_,_) when Min > Max -> ok;
toInitiateThreads(Max,Min,Data,CustomerThreads,BanksMap) when Max >= Min ->
	Row = lists:nth(Min,Data),
	Customer = element(1,Row),
	%%	Amount = element(2,Row),
	Pid = maps:get(Customer,CustomerThreads),
	Pid ! {initiate,BanksMap},
toInitiateThreads(Max,Min+1,Data,CustomerThreads,BanksMap).


loanReq(Customer,Amount,LoanAmount,MasterPid,BanksMap) ->
receive
{initiate,BanksMap} ->
	KeySet = maps:keys(BanksMap),
	%% 			io:fwrite("~p~n",[Amount]),
	applyLoan(Customer,Amount,BanksMap,KeySet,self(),MasterPid),
	loanReq(Customer,Amount,LoanAmount,MasterPid,BanksMap); 
{reply,_, AmountSanc,"Approval Pass"} ->
	KeySet = maps:keys(BanksMap),  	
	if 
	length(KeySet) > 0 ->
	if 
	Amount-AmountSanc > 0 ->
	UpdatedAmount = Amount-AmountSanc,
	applyLoan(Customer,UpdatedAmount,BanksMap,KeySet,self(),MasterPid),
	loanReq(Customer,UpdatedAmount,LoanAmount,MasterPid,BanksMap);
	Amount - AmountSanc == 0 ->
	MasterPid ! {flag1, Customer,0};

	true ->
	MasterPid ! {flag0, Customer,Amount - AmountSanc}

	end,
	loanReq(Customer,Amount-AmountSanc,LoanAmount,MasterPid,BanksMap);
	true ->
	MasterPid ! {flag0, Customer, Amount - AmountSanc}
	end,
	loanReq(Customer,Amount,LoanAmount,MasterPid,BanksMap);

{reply,BankName,_,"Approval Fail"}->
	UpdatedMaps = maps:remove(BankName,BanksMap),
	KeySet = maps:keys(UpdatedMaps),
	if 
		length(KeySet) > 0 ->
		if 
			Amount > 0 ->
			applyLoan(Customer,Amount,UpdatedMaps,KeySet,self(),MasterPid),
			loanReq(Customer,Amount,LoanAmount,MasterPid,UpdatedMaps);
			Amount  == 0 ->
			MasterPid ! {flag1, Customer,0}
		end,
		loanReq(Customer,Amount,LoanAmount,MasterPid,BanksMap);

	length(KeySet) == 0 ->
	MasterPid ! {flag0, Customer,Amount};
	true ->
	MasterPid ! {flag0, Customer,Amount}

	end
end.

%% Other ->
%% io:fwrite("Approval Fail")

createThreads(CData,BanksMap, MasterPid)->
CustomerThreads = toCreateThreads(length(CData),1,CData,#{},MasterPid, BanksMap),
toInitiateThreads(length(CData),1,CData,CustomerThreads,BanksMap),
CustomerThreads.
