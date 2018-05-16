Read("read_hpc.g");
Read("main_full_par_trafo.g");

prepareCounters := function()
    Sleep(1);
    THREAD_COUNTERS_ENABLE();
    THREAD_COUNTERS_RESET();
    return ThreadID(CurrentThread());
end;

getCountersForTaskThreads := function()
    local counters;
    Sleep(1);
    counters := [ThreadID(CurrentThread())];
    Append(counters, THREAD_COUNTERS_GET());
    return counters;
end;

prepare := function(nrAvailableThreads)
    local tasks, taskNumbers;
    tasks := List([1..nrAvailableThreads],
                  x -> RunTask(prepareCounters));
    taskNumbers := List(tasks, TaskResult);
    if Size(Set(taskNumbers)) <> GAPInfo.KernelInfo.NUM_CPUS then
        ErrorNoReturn("GaussPar: Unable to activate counters for all threads");
    fi;
end;

compute := function(A, q, numberChops)
    return GET_REAL_TIME_OF_FUNCTION_CALL(ChiefParallel,
                                            [GF(q), A, numberChops, numberChops]);
end;

evaluate := function(nrAvailableThreads, bench, A)
    local CPUTimeCompute, resPar, benchStd, resStd, correct, counters,
    totalAcquired, totalContended, factor;
    CPUTimeCompute := time;
    resPar := bench.result;
    Print("Wall time  parallel execution: ", bench.time, "\n");
    Print("CPU  time  parallel execution: ", CPUTimeCompute*1000, "\n");
    benchStd := GET_REAL_TIME_OF_FUNCTION_CALL(EchelonMatTransformation, [A]);
    resStd := benchStd.result;
    correct := -1 * resStd.vectors = resPar.vectors
           and -1 * resStd.coeffs = resPar.coeffs;
    if not correct then
        ErrorNoReturn("GaussPar: Result incorrect!");
    fi;
    Print("Wall time Gauss pkg execution: ", benchStd.time, "\n");
    counters := List([1..nrAvailableThreads], x -> RunTask(getCountersForTaskThreads));
    counters := List(counters, TaskResult);
    SortParallel(List(counters, x -> x[1]), counters);
    Print("Lock statistics(estimates):\n");
    totalAcquired := Sum(List(counters, x -> x[2]));
    totalContended := Sum(List(counters, x -> x[3]));
    Print("acquired - ", totalAcquired, ", contended - ", totalContended);
    factor := Round(totalContended / totalAcquired * 100.);
    Print(", factor - ", factor, "%\n");
    Print("Locks acquired and contention counters per thread:\n");
    Print(counters, "\n");
end;

measure_contention := function()
    local nrAvailableThreads, numberChops, n, q, A, bench;

    Print("-----------------------------------------------------\n");
    Print("Make sure you called GAP with sufficient\n");
    Print("preallocated memory via `-m`\n");
    Print("-----------------------------------------------------\n");

    nrAvailableThreads := GAPInfo.KernelInfo.NUM_CPUS;
    bench := "";
    n := 4000;; numberChops := 8;; q := 5;;
    A := RandomMat(n, n, GF(q));;
    
    prepare(nrAvailableThreads);;
    bench := compute(A, q, numberChops);;
    evaluate(nrAvailableThreads, bench);;
end;
