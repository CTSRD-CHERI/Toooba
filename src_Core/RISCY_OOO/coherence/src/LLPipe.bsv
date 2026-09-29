
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
import FShow::*;
import Types::*;
import CCTypes::*;
import CacheUtils::*;
import CCPipe::*;
import RWBramCore::*;
import RandomReplace::*;

export LLPipeCRqIn(..);
export LLPipeMRsIn(..);
export LLPipeIn(..);
export LLCmd(..);
export LLPipe(..);
export mkLLPipe;

// type param ordering: bank < child < way < index < tag < cRq

// input types
typedef struct {
    Addr addr;
    cRqIdxT mshrIdx;
} LLPipeCRqIn#(type cRqIdxT) deriving(Bits, Eq, FShow);

typedef struct {
    Addr addr;
    Msi toState; // come from req in MSHR (E or M)
    Line data; // come from memory must be valid
    wayT way; // come from MSHR
} LLPipeMRsIn#(type wayT) deriving(Bits, Eq, FShow);

typedef union tagged {
    LLPipeCRqIn#(cRqIdxT) CRq;
    CRsMsg#(childT) CRs;
    LLPipeMRsIn#(wayT) MRs;
} LLPipeIn#(
    type childT,
    type wayT,
    type cRqIdxT
) deriving (Bits, Eq, FShow);

// output cmd to the processing rule in LLC
typedef union tagged {
    cRqIdxT LLCRq; // mshr idx of the cRq
    childT LLCRs; // which child is downgrading
    void LLMRs;
} LLCmd#(type childT, type cRqIdxT) deriving (Bits, Eq, FShow);

interface LLPipe#(
    numeric type lgBankNum,
    numeric type childNum,
    numeric type wayNum,
    type indexT,
    type tagT,
    type cRqIdxT
);
    method Action send(LLPipeIn#(Bit#(TLog#(childNum)), Bit#(TLog#(wayNum)), cRqIdxT) r);
    method Action startCRsAccess(CRsAccessMsg#(Bit#(TLog#(childNum))) first);
    method Bool crsAccessReady;
    method Action putCRsAccess(CRsAccessMsg#(Bit#(TLog#(childNum))) flit);
    method Bool notEmpty;
    method PipeOut#(
        Bit#(TLog#(wayNum)),
        tagT, Msi, Vector#(childNum, Msi),
        Maybe#(CRqOwner#(cRqIdxT)), void, RandRepInfo, // no other
        Line, void, LLCmd#(Bit#(TLog#(childNum)), cRqIdxT) // no aux set data
    ) first;
    method PipeOut#(
        Bit#(TLog#(wayNum)),
        tagT, Msi, Vector#(childNum, Msi),
        Maybe#(CRqOwner#(cRqIdxT)), void, RandRepInfo, // no other
        Line, void, LLCmd#(Bit#(TLog#(childNum)), cRqIdxT) // no aux set data
    ) unguard_first;
    method Action deqWrite(
        Maybe#(cRqIdxT) swapRq,
        RamData#(tagT, Msi, Vector#(childNum, Msi), Maybe#(CRqOwner#(cRqIdxT)), void, Line) wrRam, // always write BRAM
        Bool updateRep
    );
endinterface

// real cmd used in pipeline
typedef struct {
    Addr addr;
    childT child;
} LLPipeCRsCmd#(type childT) deriving(Bits, Eq, FShow);

typedef struct {
    Addr addr;
    wayT way;
} LLPipeMRsCmd#(type wayT) deriving(Bits, Eq, FShow);

typedef union tagged {
    LLPipeCRqIn#(cRqIdxT) CRq;
    LLPipeCRsCmd#(childT) CRs;
    LLPipeMRsCmd#(wayT) MRs;
} LLPipeCmd#(
    type childT,
    type wayT,
    type cRqIdxT
) deriving (Bits, Eq, FShow);

module mkLLPipe(
    LLPipe#(lgBankNum, childNum, wayNum, indexT, tagT, cRqIdxT)
) provisos(
    Alias#(childT, Bit#(TLog#(childNum))),
    Alias#(wayT, Bit#(TLog#(wayNum))),
    Alias#(dirT, Vector#(childNum, Msi)),
    Alias#(ownerT, Maybe#(CRqOwner#(cRqIdxT))),
    Alias#(otherT, void), // no other cache info
    Alias#(repT, RandRepInfo), // use random replace
    Alias#(pipeInT, LLPipeIn#(childT, wayT, cRqIdxT)),
    Alias#(pipeCmdT, LLPipeCmd#(childT, wayT, cRqIdxT)),
    Alias#(llCmdT, LLCmd#(childT, cRqIdxT)),
    Alias#(pipeOutT, PipeOut#(wayT, tagT, Msi, dirT, ownerT, otherT, repT, Line, void, llCmdT)), // output type
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
    Alias#(cRqIdxT, Bit#(_cRqIdxSz)),
    Add#(indexSz, a__, AddrSz),
    Add#(tagSz, b__, AddrSz)
);

   Bool verbose = False;

    // RAMs
    Vector#(wayNum, RWBramCore#(indexT, infoT)) infoRam <- replicateM(mkRWBramCore);
    RWBramCore#(indexT, repT) repRam <- mkRandRepRam;
    RWBramCoreLineDirectWrite#(dataIndexT) dataRamDirect <- mkRWBramCoreLineDirectWrite;
    RWBramCore#(dataIndexT, Line) dataRam = interface RWBramCore;
        method wrReq = dataRamDirect.wrReq;
        method rdReq = dataRamDirect.rdReq;
        method rdResp = dataRamDirect.rdResp;
        method rdRespValid = dataRamDirect.rdRespValid;
        method deqRdResp = dataRamDirect.deqRdResp;
    endinterface;
    RWBramCore#(indexT, void) setAuxDataRam <- mkDummyBramCore;

    // initialize RAM
    Reg#(Bool) initDone <- mkReg(False);
    Reg#(indexT) initIndex <- mkReg(0);

    rule doInit(!initDone);
        for(Integer i = 0; i < valueOf(wayNum); i = i+1) begin
            infoRam[i].wrReq(initIndex, CacheInfo {
                tag: 0,
                cs: I,
                dir: replicate(I),
                owner: Invalid,
                other: ?
            });
        end
        repRam.wrReq(initIndex, randRepInitInfo); // useless for random replace
        initIndex <= initIndex + 1;
        if(initIndex == maxBound) begin
            initDone <= True;
        end
    endrule

    // random replacement
    RandomReplace#(wayNum) randRep <- mkRandomReplace;

    // functions
    function Bool isCRsCmd(pipeCmdT cmd);
        return case (cmd) matches
            tagged CRs .*: True;
            default: False;
        endcase;
    endfunction

    function Addr getAddrFromCmd(pipeCmdT cmd);
        return (case(cmd) matches
            tagged CRq .r: r.addr;
            tagged CRs .r: r.addr;
            tagged MRs .r: r.addr;
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
            $display("%t LL %m tagMatch: ", $time,
                fshow(cmd), " ; ",
                fshow(getTag(getAddrFromCmd(cmd))), " ; ",
                fshow(tagVec), " ; ",
                fshow(csVec), " ; ",
                fshow(ownerVec)
            );
            if(cmd matches tagged MRs .rs) begin
                // MRs directly read from cmd
                return TagMatchResult {
                    way: rs.way,
                    pRqMiss: False
                };
            end
            else begin
                // CRq/CRs: need tag matching
                Addr addr = getAddrFromCmd(cmd);
                tagT tag = getTag(addr);
                // find hit way (we do not check replacing bit in LLC)
                // this makes <cRq a> blocked by other <cRq b> which is replacing addr a
                function Bool isMatch(Tuple2#(Msi, tagT) csTag);
                    match {.cs, .t} = csTag;
                    return cs > I && t == tag;
                endfunction
                Maybe#(wayT) hitWay = searchIndex(isMatch, zip(csVec, tagVec));
                if(hitWay matches tagged Valid .w) begin
                    return TagMatchResult {
                        way: w,
                        pRqMiss: False
                    };
                end
                else begin
                    // cRs must hit, so only cRq cannot enter here
                    doAssert(cmd matches tagged CRq ._rq ? True : False,
                        "only cRq can tag match miss"
                    );
                    // find a unlocked way to replace for cRq
                    Vector#(wayNum, Bool) unlocked = ?;
                    Vector#(wayNum, Bool) invalid = ?;
                    for(Integer i = 0; i < valueOf(wayNum); i = i+1) begin
                        invalid[i] = csVec[i] == I;
                        unlocked[i] = !isValid(ownerVec[i]);
                    end
                    Maybe#(wayT) repWay = randRep.getReplaceWay(unlocked, invalid);
                    // sanity check: repWay must be valid
                    doAssert(isValid(repWay), "should always find a way to replace");
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
        doAssert((oldCs == I || (oldCs == T && toState >= S)) && dataV, "LLC mRs always has data");
        return UpdateByUpCs {cs: toState};
    endactionvalue
    endfunction

    function ActionValue#(updateByDownDirT) updateByDownDir(
        pipeCmdT cmd, Msi toState, Bool dataV, Msi oldCs, dirT oldDir
    );
    actionvalue
        // update dir
        dirT newDir = oldDir;
        if(cmd matches tagged CRs .cRs) begin
            if(dataV) begin
                doAssert(oldDir[cRs.child] >= E, "cRs with data, dir must >= E");
            end
            else begin
                doAssert(oldDir[cRs.child] < M, "cRs without data, dir must < M");
            end
            if(oldDir[cRs.child] == M) begin
                doAssert(dataV, "must have data");
            end
            newDir[cRs.child] = toState;
        end
        else begin
            // should not happen
            doAssert(False, "only cRs updates dir");
        end
        // update cs
        // XXX since child can upgrade from E to M silently, use data valid
        // to determine if we need to upgrade to M. Note that the data
        // valid field has not been overwritten by bypass in CCPipe.
        Msi newCs = oldCs;
        if(dataV) begin
            doAssert(oldCs >= E, "cRs has data, cs must >= E");
            newCs = M;
        end
        return UpdateByDownDir {cs: newCs, dir: newDir};
    endactionvalue
    endfunction

    function ActionValue#(repT) updateRepInfo(repT r, wayT w);
    actionvalue
        return ?; // random replace does not have bookkeeping
    endactionvalue
    endfunction

    CCPipe#(wayNum, indexT, tagT, Msi, dirT, ownerT, otherT, repT, Line, void, pipeCmdT) pipe <- mkCCPipe(
        regToReadOnly(initDone), getIndex, tagMatch,
        updateByUpCs, updateByDownDir, updateRepInfo,
        infoRam, repRam, dataRam, setAuxDataRam
    );

    // State for a child response whose data is written one access at a time.
    Reg#(Bool) crsActive <- mkReg(False);
    Reg#(Bool) crsComplete <- mkReg(False);
    Reg#(Bool) crsHasData <- mkReg(False);
    Reg#(Addr) crsAddr <- mkReg(0);
    Reg#(childT) crsChild <- mkReg(0);
    Reg#(Msi) crsToState <- mkReg(I);
    Reg#(CLineAccessSel) crsExpectedAccess <- mkReg(0);
    Vector#(CLineNumAccesses, Reg#(CLineAccess)) crsLine <- replicateM(mkReg(unpack(0)));

    function Line getCRsLine;
        Vector#(CLineNumAccesses, CLineAccess) accesses = readVReg(crsLine);
        return accessVectorToCline(accesses);
    endfunction

    // get first output from CCPipe output
    function pipeOutT getFirst(PipeOut#(wayT, tagT, Msi, dirT, ownerT, otherT, repT, Line, void, pipeCmdT) pout);
        let result = PipeOut {
            cmd: (case(pout.cmd) matches
                tagged CRq .rq: LLCRq (rq.mshrIdx);
                tagged CRs .rs: LLCRs (rs.child);
                tagged MRs .rs: LLMRs;
                default: ?;
            endcase),
            way: pout.way,
            pRqMiss: pout.pRqMiss,
            ram: pout.ram,
            repInfo: pout.repInfo,
            setAuxData: ?
        };
        if (crsActive && crsComplete && crsHasData && isCRsCmd(pout.cmd))
            result.ram.line = getCRsLine;
        return result;
    endfunction

    method Action send(pipeInT req) if (!crsActive);
        case(req) matches
            tagged CRq .rq: begin
                pipe.enq(CRq (rq), Invalid, Invalid);
            end
            tagged CRs .rs: begin
                pipe.enq(CRs (LLPipeCRsCmd {
                    addr: rs.addr,
                    child: rs.child
                }), rs.data, DownDir (rs.toState));
            end
            tagged MRs .rs: begin
                pipe.enq(MRs (LLPipeMRsCmd {
                    addr: rs.addr,
                    way: rs.way
                }), Valid (rs.data), UpCs (rs.toState));
            end
        endcase
    endmethod

    method Action startCRsAccess(CRsAccessMsg#(childT) first) if (!crsActive);
        doAssert(first.access == 0, "streamed child response must start at access zero");
        crsActive <= True;
        crsComplete <= False;
        crsHasData <= isValid(first.data);
        crsAddr <= first.addr;
        crsChild <= first.child;
        crsToState <= first.toState;
        crsExpectedAccess <= 0;
        pipe.enq(CRs (LLPipeCRsCmd {addr: first.addr, child: first.child}),
                 isValid(first.data) ? Valid(unpack(0)) : Invalid,
                 DownDir(first.toState));
    endmethod

    method Bool crsAccessReady = crsActive && pipe.notEmpty && !crsComplete;

    method Action putCRsAccess(CRsAccessMsg#(childT) flit)
        if (crsActive && pipe.notEmpty && !crsComplete);
        doAssert(flit.addr == crsAddr && flit.child == crsChild && flit.toState == crsToState,
                 "streamed child response metadata changed within burst");
        doAssert(flit.access == crsExpectedAccess,
                 "streamed child response access arrived out of order");
        doAssert(isValid(flit.data) == crsHasData,
                 "streamed child response data validity changed within burst");
        if (flit.data matches tagged Valid .accessData) begin
            let pout = pipe.first;
            dataRamDirect.wrAccess(getDataRamIndex(pout.way, getIndex(pout.cmd)), flit.access, accessData);
            crsLine[flit.access] <= accessData;
        end
        if (flit.last) begin
            doAssert(crsHasData
                         ? flit.access == fromInteger(valueOf(CLineNumAccesses) - 1)
                         : flit.access == 0,
                     "streamed child response ended at an invalid access");
            crsComplete <= True;
        end
        else begin
            doAssert(crsHasData, "non-final streamed child response must carry data");
            crsExpectedAccess <= crsExpectedAccess + 1;
        end
    endmethod

    // need to adapt pipeline output to real output format
    method pipeOutT first if (pipe.notEmpty && (!crsActive || crsComplete));
        return getFirst(pipe.first); // guarded version
    endmethod

    method pipeOutT unguard_first;
        return getFirst(pipe.unguard_first); // unguarded version
    endmethod

    method notEmpty = pipe.notEmpty && (!crsActive || crsComplete);

    method Action deqWrite(Maybe#(cRqIdxT) swapRq, ramDataT wrRam, Bool updateRep);
        // get new cmd
        Addr addr = getAddrFromCmd(pipe.first.cmd); // inherit addr
        Maybe#(pipeCmdT) newCmd = Invalid;
        if(swapRq matches tagged Valid .idx) begin
            newCmd = Valid (CRq (LLPipeCRqIn {addr: addr, mshrIdx: idx}));
        end
        // Streamed CRs data has already been written bank-by-bank.
        if (crsActive && isCRsCmd(pipe.first.cmd)) begin
            pipe.deqWriteNoData(newCmd, wrRam, ?, updateRep);
            crsActive <= False;
            crsComplete <= False;
            crsHasData <= False;
            crsExpectedAccess <= 0;
        end
        else begin
            pipe.deqWrite(newCmd, wrRam, ?, updateRep);
        end
    endmethod
endmodule
