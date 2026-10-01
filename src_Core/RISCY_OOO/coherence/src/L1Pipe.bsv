
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jonathan Woodruff
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//-
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Vector::*;
import Ehr::*;
import FShow::*;
import Types::*;
import CCTypes::*;
import CacheUtils::*;
import CCPipe::*;
import RWBramCore::*;
import RandomReplace::*;

export L1PipeRqIn(..);
export L1PipePRsIn(..);
export L1PipeFlushIn(..);
export L1PipeIn(..);
export L1FlushCmd(..);
export L1Cmd(..);
export L1Pipe(..);
export mkL1Pipe;

// type param ordering: bank < way < index < tag < cRq < pRq

// in L1 cache, only cRq can occupy cache line (pRq handled immediately)
// replacement is always done immediately (never have replacing line)
// so cache owner type is simply Maybe#(cRqIdxT)

// input types
typedef struct {
    Addr addr;
    rqIdxT mshrIdx;
    Bool readWholeLine;
} L1PipeRqIn#(type rqIdxT) deriving(Bits, Eq, FShow);

typedef struct {
    Addr addr;
    Msi toState;
    Maybe#(Line) data;
    wayT way;
} L1PipePRsIn#(type wayT) deriving(Bits, Eq, FShow);

typedef struct {
    indexT index;
    wayT way;
    pRqIdxT mshrIdx;
} L1PipeFlushIn#(
    type wayT,
    type indexT,
    type pRqIdxT
) deriving(Bits, Eq, FShow);

typedef union tagged {
    L1PipeRqIn#(cRqIdxT) CRq;
    L1PipeRqIn#(pRqIdxT) PRq;
    L1PipePRsIn#(wayT) PRs;
`ifdef SECURITY_CACHES
    L1PipeFlushIn#(wayT, indexT, pRqIdxT) Flush;
`endif
} L1PipeIn#(
    type wayT,
    type indexT,
    type cRqIdxT,
    type pRqIdxT
) deriving (Bits, Eq, FShow);

// output cmd to the processing rule in L1$
typedef struct {
    indexT index;
    pRqIdxT mshrIdx;
} L1FlushCmd#(type indexT, type pRqIdxT) deriving(Bits, Eq, FShow);

typedef union tagged {
    cRqIdxT L1CRq;
    pRqIdxT L1PRq;
    void L1PRs;
`ifdef SECURITY_CACHES
    L1FlushCmd#(indexT, pRqIdxT) L1Flush;
`endif
} L1Cmd#(
    type indexT,
    type cRqIdxT,
    type pRqIdxT
) deriving (Bits, Eq, FShow);

interface L1Pipe#(
    numeric type lgBankNum,
    numeric type wayNum,
    type indexT,
    type tagT,
    type cRqIdxT,
    type pRqIdxT
);
    method Action send(L1PipeIn#(Bit#(TLog#(wayNum)), indexT, cRqIdxT, pRqIdxT) r);
    method Action startPRsAccess(PRsAccessMsg#(Bit#(TLog#(wayNum)), void) first);
    method Bool prsAccessReady;
    method Action putPRsAccess(PRsAccessMsg#(Bit#(TLog#(wayNum)), void) flit);
    method PipeOut#(
        Bit#(TLog#(wayNum)),
        tagT, Msi, void, // no dir
        Maybe#(cRqIdxT), void, RandRepInfo, // no other
        Line, Maybe#(cRqIdxT), L1Cmd#(indexT, cRqIdxT, pRqIdxT)
    ) first;
    method Action deqWrite(
        Maybe#(cRqIdxT) swapRq,
        RamData#(tagT, Msi, void, Maybe#(cRqIdxT), void, Line) wrRam, // always write BRAM
        Maybe#(cRqIdxT) nextInQueue,
        Bool updateRep
    );
endinterface

// real cmd used in pipeline
typedef struct {
    Addr addr;
    wayT way;
} L1PipePRsCmd#(type wayT) deriving(Bits, Eq, FShow);

typedef union tagged {
    L1PipeRqIn#(cRqIdxT) CRq;
    L1PipeRqIn#(pRqIdxT) PRq;
    L1PipePRsCmd#(wayT) PRs;
`ifdef SECURITY_CACHES
    L1PipeFlushIn#(wayT, indexT, pRqIdxT) Flush;
`endif
} L1PipeCmd#(
    type wayT,
    type indexT,
    type cRqIdxT,
    type pRqIdxT
) deriving (Bits, Eq, FShow);

module mkL1Pipe(
    L1Pipe#(lgBankNum, wayNum, indexT, tagT, cRqIdxT, pRqIdxT)
) provisos(
    Alias#(wayT, Bit#(TLog#(wayNum))),
    Alias#(dirT, void), // no directory
    Alias#(ownerT, Maybe#(cRqIdxT)),
    Alias#(otherT, void), // no other cache info
    Alias#(setAuxT, Maybe#(cRqIdxT)),
    Alias#(repT, RandRepInfo), // use random replace
    Alias#(pipeInT, L1PipeIn#(wayT, indexT, cRqIdxT, pRqIdxT)),
    Alias#(pipeCmdT, L1PipeCmd#(wayT, indexT, cRqIdxT, pRqIdxT)),
    Alias#(l1CmdT, L1Cmd#(indexT, cRqIdxT, pRqIdxT)),
    Alias#(pipeOutT, PipeOut#(wayT, tagT, Msi, dirT, ownerT, otherT, repT, Line, setAuxT, l1CmdT)), // output type
    Alias#(infoT, CacheInfo#(tagT, Msi, dirT, ownerT, otherT)),
    Alias#(ramDataT, RamData#(tagT, Msi, dirT, ownerT, otherT, Line)),
    Alias#(respStateT, RespState#(Msi)),
    Alias#(tagMatchResT, TagMatchResult#(wayT)),
    Alias#(updateByUpCsT, UpdateByUpCs#(Msi)),
    Alias#(updateByDownDirT, UpdateByDownDir#(Msi, dirT)),
    Alias#(dataIndexT, Bit#(TAdd#(TLog#(wayNum), indexSz))),
    // requirement
    Alias#(indexT, Bit#(indexSz)),
    Alias#(tagT, Bit#(tagSz)),
    Alias#(cRqIdxT, Bit#(cRqIdxSz)),
    Alias#(pRqIdxT, Bit#(pRqIdxSz)),
    Add#(indexSz, a__, AddrSz),
    Add#(tagSz, b__, AddrSz)
);

   Bool verbose = False;

    // RAMs
    Vector#(wayNum, RWBramCore#(indexT, infoT)) infoRam <- replicateM(mkRWBramCoreForwarded);
    RWBramCore#(indexT, repT) repRam <- mkRandRepRam;
    Vector#(wayNum, RWBramCoreLineDirectWrite#(indexT)) dataRamDirect <- replicateM(mkRWBramCoreLineDirectWriteForwarded);
    Vector#(wayNum, RWBramCore#(indexT, Line)) dataRam = newVector;
    for (Integer i = 0; i < valueOf(wayNum); i = i + 1) begin
        dataRam[i] = interface RWBramCore;
            method wrReq = dataRamDirect[i].wrReq;
            method rdReq = dataRamDirect[i].rdReq;
            method rdResp = dataRamDirect[i].rdResp;
            method rdRespValid = dataRamDirect[i].rdRespValid;
            method deqRdResp = dataRamDirect[i].deqRdResp;
        endinterface;
    end
    RWBramCore#(indexT, setAuxT) queueRam <- mkRWBramCoreForwarded;

    // initialize RAM
    Reg#(Bool) initDone <- mkReg(False);
    Reg#(indexT) initIndex <- mkReg(0);

    rule doInit(!initDone);
        for(Integer i = 0; i < valueOf(wayNum); i = i+1) begin
            infoRam[i].wrReq(initIndex, CacheInfo {
                tag: 0,
                cs: I,
                dir: ?,
                owner: Invalid,
                other: ?
            });
        end
        repRam.wrReq(initIndex, randRepInitInfo); // useless for random replace
        queueRam.wrReq(initIndex, Invalid);
        initIndex <= initIndex + 1;
        if(initIndex == maxBound) begin
            initDone <= True;
        end
    endrule

    // random replacement
    RandomReplace#(wayNum) randRep <- mkRandomReplace;

    // functions
    function Addr getAddrFromCmd(pipeCmdT cmd);
        return (case(cmd) matches
            tagged CRq .r: r.addr;
            tagged PRq .r: r.addr;
            tagged PRs .r: r.addr;
`ifdef SECURITY_CACHES
            // fake an address for flush req that has the same index
            tagged Flush .r: (zeroExtend(r.index) << (valueOf(LgLineSzBytes) + valueOf(lgBankNum)));
`endif
            default: ?;
        endcase);
    endfunction

    function indexT getIndex(pipeCmdT cmd);
        Addr a = getAddrFromCmd(cmd);
        return truncate(a >> (valueOf(LgLineSzBytes) + valueOf(lgBankNum)));
    endfunction

    function ActionValue#(tagMatchResT) tagMatch(
        pipeCmdT cmd,
        Vector#(wayNum, tagT) tagVec,
        Vector#(wayNum, Msi) csVec,
        Vector#(wayNum, ownerT) ownerVec,
        repT repInfo
    );
        return actionvalue
            function tagT getTag(Addr a) = truncateLSB(a);

            if (verbose)
            $display("%t L1 %m tagMatch: ", $time,
                fshow(cmd), " ; ",
                fshow(getTag(getAddrFromCmd(cmd))),
                fshow(tagVec), " ; ",
                fshow(csVec), " ; ",
                fshow(ownerVec), " ; "
            );
            if(cmd matches tagged PRs .rs) begin
                // PRs directly read from cmd
                return TagMatchResult {
                    way: rs.way,
                    pRqMiss: False
                };
            end
`ifdef SECURITY_CACHES
            else if(cmd matches tagged Flush .flush) begin
                // flush directly read from cmd
                return TagMatchResult {
                    way: flush.way,
                    pRqMiss: False
                };
            end
`endif
            else begin
                // CRq/PRq: need tag matching
                Addr addr = getAddrFromCmd(cmd);
                tagT tag = getTag(addr);
                // find hit way (nothing is being replaced)
                function Bool isMatch(Tuple3#(Msi, tagT, ownerT) csTagOwner);
                    match {.cs, .t, .o} = csTagOwner;
                    Bool cRqHit = (cs > I || isValid(o)) && t == tag;
                    Bool pRqHit = cs > I && t == tag;
                    return cmd matches tagged CRq .* ? cRqHit : pRqHit;
                endfunction
                Maybe#(wayT) hitWay = searchIndex(isMatch, zip3(csVec, tagVec, ownerVec));
                if(hitWay matches tagged Valid .w) begin
                    return TagMatchResult {
                        way: w,
                        pRqMiss: False
                    };
                end
                else if(cmd matches tagged PRq .rq) begin
                    // pRq miss
                    return TagMatchResult {
                        way: 0, // default to 0
                        pRqMiss: True
                    };
                end
                else begin
                    // find a unlocked way to replace for cRq
                    Vector#(wayNum, Bool) unlocked = ?;
                    Vector#(wayNum, Bool) invalid = ?;
                    for(Integer i = 0; i < valueOf(wayNum); i = i+1) begin
                        invalid[i] = csVec[i] == I;
                        unlocked[i] = !isValid(ownerVec[i]);
                    end
                    Maybe#(wayT) repWay = randRep.getReplaceWay(unlocked, invalid);
                    // There may be no way to replace if all ways are locked.
                    // Just choose a locked way. This will cause the request to be queued.
                    if(verbose && !isValid(repWay)) begin
                        $display("%t L1 %m tagMatch: set oversubscription", $time);
                    end
                    return TagMatchResult {
                        way: fromMaybe(?, repWay),
                        pRqMiss: False
                    };
                end
            end
        endactionvalue;
    endfunction

    function ActionValue#(updateByUpCsT) updateByUpCs(
        pipeCmdT cmd, Msi toState, Bool dataV, Msi oldCs
    );
    actionvalue
        doAssert(toState > oldCs, "should truly upgrade cs");
        doAssert((oldCs < S) == dataV, "valid resp data when data already up to date");
        return UpdateByUpCs {cs: toState};
    endactionvalue
    endfunction

    function ActionValue#(updateByDownDirT) updateByDownDir(
        pipeCmdT cmd, Msi toState, Bool dataV, Msi oldCs, dirT oldDir
    );
    actionvalue
        doAssert(False, "L1 does not have dir");
        return UpdateByDownDir {cs: oldCs, dir: oldDir};
    endactionvalue
    endfunction

    function ActionValue#(repT) updateRepInfo(repT r, wayT w);
    actionvalue
        return ?; // random replace does not have bookkeeping
    endactionvalue
    endfunction

    // CCPipe performs metadata lookup and way selection only. Data is read
    // explicitly from the selected way after tag match.
    Vector#(wayNum, RWBramCore#(indexT, void)) dummyDataRam <- replicateM(mkDummyBramCore);
    CCPipe#(
        wayNum, indexT, tagT, Msi, dirT, ownerT, otherT, repT, void, setAuxT, pipeCmdT
    ) pipe <- mkCCPipeSingleCycle(
        regToReadOnly(initDone), getIndex, tagMatch,
        updateByUpCs, updateByDownDir, updateRepInfo,
        infoRam, repRam, dummyDataRam, queueRam
    );

    Reg#(Bool) lineReadIssued <- mkReg(False);
    Reg#(Bool) lineReadWhole <- mkReg(False);
    Reg#(CLineAccessSel) lineReadAccess <- mkReg(0);
    Ehr#(2, Maybe#(Line)) lineReadDataEhr <- mkEhr(Invalid);
    Reg#(Maybe#(Line)) lineReadData = lineReadDataEhr[0];
    Reg#(Maybe#(Line)) lineReadDataDeq = lineReadDataEhr[1];
    Reg#(Maybe#(Line)) legacyPRsLine <- mkReg(Invalid);

    Reg#(Bool) prsActive <- mkReg(False);
    Reg#(Bool) prsComplete <- mkReg(False);
    Reg#(Bool) prsHasData <- mkReg(False);
    Reg#(Addr) prsAddr <- mkReg(0);
    Reg#(Msi) prsToState <- mkReg(I);
    Reg#(wayT) prsWay <- mkReg(0);
    Reg#(CLineAccessSel) prsExpectedAccess <- mkReg(0);
    Vector#(CLineNumAccesses, Reg#(CLineAccess)) prsLine <- replicateM(mkReg(unpack(0)));

    function Bool isPRsCmd(pipeCmdT cmd);
        return case (cmd) matches
            tagged PRs .*: True;
            default: False;
        endcase;
    endfunction

    function Line getPRsLine;
        return accessVectorToCline(readVReg(prsLine));
    endfunction

    function Bool isActivePRsCmd(pipeCmdT cmd);
        return case (cmd) matches
            tagged PRs .rs: prsActive && rs.addr == prsAddr && rs.way == prsWay;
            default: False;
        endcase;
    endfunction

    function Bool responseSuppliesLine(pipeCmdT cmd);
        return (isActivePRsCmd(cmd) && prsHasData)
               || (isPRsCmd(cmd) && isValid(legacyPRsLine));
    endfunction

    rule issueSelectedLineRead(pipe.notEmpty && !lineReadIssued && !isValid(lineReadData)
                               && !responseSuppliesLine(pipe.first.cmd));
        let pout = pipe.first;
        Addr addr = getAddrFromCmd(pout.cmd);
        Bool readWhole = case (pout.cmd) matches
            tagged CRq .rq:
                rq.readWholeLine
                || (pout.ram.info.cs == M && pout.ram.info.tag != truncateLSB(rq.addr));
            tagged PRq .*: pout.ram.info.cs == M;
            tagged PRs .*: True;
`ifdef SECURITY_CACHES
            tagged Flush .*: pout.ram.info.cs == M;
`endif
            default: True;
        endcase;
        CLineAccessSel access = getCLineAccessSel(addr);
        if (readWhole)
            dataRam[pout.way].rdReq(getIndex(pout.cmd));
        else
            dataRamDirect[pout.way].rdAccessReq(getIndex(pout.cmd), access);
        lineReadWhole <= readWhole;
        lineReadAccess <= access;
        lineReadIssued <= True;
    endrule

    rule collectSelectedLineRead(pipe.notEmpty && lineReadIssued);
        let pout = pipe.first;
        Line line = unpack(0);
        if (lineReadWhole) begin
            line = dataRam[pout.way].rdResp;
            dataRam[pout.way].deqRdResp;
        end
        else begin
            Vector#(CLineNumAccesses, CLineAccess) accesses = replicate(unpack(0));
            accesses[lineReadAccess] = dataRamDirect[pout.way].rdAccessResp(lineReadAccess);
            dataRamDirect[pout.way].deqRdAccessResp(lineReadAccess);
            line = accessVectorToCline(accesses);
        end
        lineReadData <= Valid(line);
        lineReadIssued <= False;
    endrule

    method Action send(pipeInT req) if (!prsActive);
        case(req) matches
            tagged CRq .rq: begin
                pipe.enq(CRq (rq), Invalid, Invalid);
            end
            tagged PRq .rq: begin
                pipe.enq(PRq (rq), Invalid, Invalid);
            end
            tagged PRs .rs: begin
                legacyPRsLine <= rs.data;
                pipe.enq(PRs (L1PipePRsCmd {
                    addr: rs.addr,
                    way: rs.way
                }), isValid(rs.data) ? Valid(?) : Invalid, UpCs (rs.toState));
            end
`ifdef SECURITY_CACHES
            tagged Flush .flush: begin
                pipe.enq(Flush (flush), Invalid, Invalid);
            end
`endif
        endcase
    endmethod

    method Action startPRsAccess(PRsAccessMsg#(wayT, void) first) if (!prsActive);
        doAssert(first.access == 0, "streamed parent response must start at access zero");
        prsActive <= True;
        prsComplete <= False;
        prsHasData <= isValid(first.data);
        prsAddr <= first.addr;
        prsToState <= first.toState;
        prsWay <= first.id;
        prsExpectedAccess <= 0;
        legacyPRsLine <= Invalid;
        pipe.enq(PRs (L1PipePRsCmd {addr: first.addr, way: first.id}),
                 isValid(first.data) ? Valid(?) : Invalid,
                 UpCs(first.toState));
    endmethod

    method Bool prsAccessReady = prsActive && pipe.notEmpty && !prsComplete
                                 && isActivePRsCmd(pipe.first.cmd);

    method Action putPRsAccess(PRsAccessMsg#(wayT, void) flit)
        if (prsActive && pipe.notEmpty && !prsComplete
            && isActivePRsCmd(pipe.first.cmd));
        doAssert(flit.addr == prsAddr && flit.id == prsWay && flit.toState == prsToState,
                 "streamed parent response metadata changed within burst");
        doAssert(flit.access == prsExpectedAccess,
                 "streamed parent response access arrived out of order");
        doAssert(isValid(flit.data) == prsHasData,
                 "streamed parent response data validity changed within burst");
        let pout = pipe.first;
        doAssert(pout.way == prsWay, "streamed parent response selected wrong way");
        if (flit.data matches tagged Valid .accessData) begin
            dataRamDirect[pout.way].wrAccess(getIndex(pout.cmd), flit.access, accessData);
            prsLine[flit.access] <= accessData;
        end
        if (flit.last) begin
            doAssert(prsHasData
                         ? flit.access == fromInteger(valueOf(CLineNumAccesses) - 1)
                         : flit.access == 0,
                     "streamed parent response ended at an invalid access");
            prsComplete <= True;
        end
        else begin
            doAssert(prsHasData, "non-final streamed parent response must carry data");
            prsExpectedAccess <= prsExpectedAccess + 1;
        end
    endmethod

    // need to adapt pipeline output to real output format
    method pipeOutT first if (pipe.notEmpty
                              && (!isActivePRsCmd(pipe.first.cmd) || prsComplete)
                              && (responseSuppliesLine(pipe.first.cmd) || isValid(lineReadData)));
        let pout = pipe.first;
        Line selectedLine = fromMaybe(?, lineReadData);
        if (isActivePRsCmd(pout.cmd) && prsHasData)
            selectedLine = getPRsLine;
        else if (isValid(legacyPRsLine) && isPRsCmd(pout.cmd))
            selectedLine = validValue(legacyPRsLine);
        let result = PipeOut {
            cmd: (case(pout.cmd) matches
                tagged CRq .rq: L1CRq (rq.mshrIdx);
                tagged PRq .rq: L1PRq (rq.mshrIdx);
                tagged PRs .rs: L1PRs;
`ifdef SECURITY_CACHES
                tagged Flush .flush: L1Flush (L1FlushCmd {
                    index: flush.index,
                    mshrIdx: flush.mshrIdx
                });
`endif
                default: ?;
            endcase),
            way: pout.way,
            pRqMiss: pout.pRqMiss,
            ram: RamData {info: pout.ram.info, line: selectedLine},
            repInfo: pout.repInfo,
            setAuxData: pout.setAuxData
        };
        return result;
    endmethod

    method Action deqWrite(Maybe#(cRqIdxT) swapRq, ramDataT wrRam, Maybe#(cRqIdxT) nextInQueue, Bool updateRep);
        // get new cmd
        Maybe#(pipeCmdT) newCmd = Invalid;
        if(swapRq matches tagged Valid .idx) begin // swap in cRq
            Addr addr = getAddrFromCmd(pipe.first.cmd); // inherit addr
            newCmd = Valid (CRq (L1PipeRqIn {
                addr: addr,
                mshrIdx: idx,
                // The successor's request attributes are not available here.
                // Conservatively preserve the whole-line behavior.
                readWholeLine: True
            }));
`ifdef SECURITY_CACHES
            doAssert(pipe.first.cmd matches tagged Flush .f ? False : True,
                     "Cannot swap after a flush req");
`endif
        end
        let pout = pipe.first;
        Bool streamedUnchanged = isActivePRsCmd(pout.cmd)
                                 && prsHasData && wrRam.line == getPRsLine;
        if (!streamedUnchanged) begin
            if (responseSuppliesLine(pout.cmd) || lineReadWhole)
                dataRamDirect[pout.way].wrReq(getIndex(pout.cmd), wrRam.line);
            else begin
                let accesses = clineToAccessVector(wrRam.line);
                dataRamDirect[pout.way].wrAccess(getIndex(pout.cmd), lineReadAccess,
                                                 accesses[lineReadAccess]);
            end
        end

        RamData#(tagT, Msi, dirT, ownerT, otherT, void) metaRam = RamData {
            info: wrRam.info,
            line: ?
        };
        pipe.deqWriteNoData(newCmd, metaRam, nextInQueue, updateRep);

        lineReadIssued <= False;
        lineReadDataDeq <= Invalid;
        legacyPRsLine <= Invalid;
        if (isActivePRsCmd(pout.cmd)) begin
            prsActive <= False;
            prsComplete <= False;
            prsHasData <= False;
            prsExpectedAccess <= 0;
        end
    endmethod
endmodule
