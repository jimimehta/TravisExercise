%% @author Jimi Mehta 40225526

-module(bank).

-export([createBanksThreads/2,toCreateThreads/5,loanReq/3]).

toCreateThreads(Max,Min,_,TempMap,_) when Min > Max -> TempMap;
toCreateThreads(Max,Min,Data,TempMap,MasterPid) when Min =< Max ->
	Row = lists:nth(Min,Data),
	BankName = element(1,Row),
	BankBalance = element(2,Row),
	Pid = spawn(bank,loanReq,[BankName,BankBalance,MasterPid]),
	%% 	io:fwrite("Thread create ~p : ~p~n",[Pid,BankName]),
	UpdatedMap = maps:put(BankName,Pid,TempMap),
toCreateThreads(Max,Min+1,Data,UpdatedMap,MasterPid).

loanReq(BankName,BankBalance, MasterPid) ->
receive
	{request,Customer,Amount,CustomerPid} ->
		
	if 
		BankBalance - Amount >= 0 -> 
			NewBal = BankBalance - Amount,
			CustomerPid ! {reply,BankName,Amount,"Approval Pass"},
			MasterPid ! {frombankApproved, BankName, Amount,Customer};
		true ->
			NewBal = BankBalance,
			CustomerPid ! {reply,BankName,Amount,"Approval Fail"},
			MasterPid ! {frombankDisApproved, BankName, Amount,Customer}
	end,
	NewBalD=loanReq(BankName,NewBal, MasterPid),
	NewBalD;
	{displayBalance} ->
		MasterPid ! {myBalance,BankName,BankBalance},
		BankBalance
end.

createBanksThreads(BData, MasterPid)->
toCreateThreads(length(BData),1,BData,#{},MasterPid).

%%	BankThreads = toCreateThreads(length(BData),1,BData,#{},MasterPid).
