#include "EngineClient.hpp"
#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

namespace cassotis {
static constexpr size_t maxPayload = 8 * 1024 * 1024;
static void require(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
void Writer::u16(uint16_t v) { for (int i=0;i<2;++i) u8(v >> (8*i)); }
void Writer::u32(uint32_t v) { for (int i=0;i<4;++i) u8(v >> (8*i)); }
void Writer::u64(uint64_t v) { for (int i=0;i<8;++i) u8(v >> (8*i)); }
void Writer::string(const std::string &v) {
    require(v.size() <= 1024*1024, "IPC string too long");
    u32(static_cast<uint32_t>(v.size())); data.insert(data.end(), v.begin(), v.end());
}
uint8_t Reader::u8() { require(offset < data.size(), "Truncated IPC payload"); return data[offset++]; }
uint16_t Reader::u16() { uint16_t v=0; for(int i=0;i<2;++i) v |= uint16_t(u8()) << (8*i); return v; }
uint32_t Reader::u32() { uint32_t v=0; for(int i=0;i<4;++i) v |= uint32_t(u8()) << (8*i); return v; }
uint64_t Reader::u64() { uint64_t v=0; for(int i=0;i<8;++i) v |= uint64_t(u8()) << (8*i); return v; }
static bool validUTF8(const uint8_t *s, size_t n) {
    for (size_t i=0;i<n;) {
        uint32_t c=s[i++]; int extra=0; uint32_t minimum=0;
        if(c<0x80) continue;
        if(c>=0xc2 && c<=0xdf) { extra=1; c&=31; minimum=0x80; }
        else if(c>=0xe0 && c<=0xef) { extra=2; c&=15; minimum=0x800; }
        else if(c>=0xf0 && c<=0xf4) { extra=3; c&=7; minimum=0x10000; }
        else return false;
        if(i+extra>n) return false;
        while(extra--) { uint8_t b=s[i++]; if((b&0xc0)!=0x80) return false; c=(c<<6)|(b&63); }
        if(c<minimum || c>0x10ffff || (c>=0xd800 && c<=0xdfff)) return false;
    }
    return true;
}
std::string Reader::string() {
    size_t n=u32(); require(n<=1024*1024 && n<=data.size()-offset,"Invalid IPC string length");
    require(validUTF8(data.data()+offset,n),"Invalid IPC UTF-8");
    std::string s(reinterpret_cast<const char *>(data.data()+offset),n); offset+=n; return s;
}
uint16_t Reader::schema() { auto v=u16(); require(u16()==0,"Invalid schema flags"); return v; }
void Reader::end() { require(offset==data.size(),"Trailing IPC payload"); }
Bytes encodeKey(const Key &k) {
    Writer w; w.schema(); w.u16(k.special); w.u16(0); w.u32(k.modifiers); w.u32(k.scan);
    w.u32((k.release?1:0)|(k.repeat?2:0)); w.u64(k.timestamp); w.string(k.text); return w.data;
}
Result decodeResult(const Bytes &data) {
    Reader r(data); require(r.schema()==1,"Unsupported result schema"); Result v;
    auto handled=r.u8(); require(handled<=1 && r.u16()==0,"Invalid result flags"); v.handled=handled;
    auto flags=r.u8(); require((flags&~1)==0,"Invalid result flags"); v.pending=flags&1;
    v.selected=int32_t(r.u32()); v.page=int32_t(r.u32()); v.pages=int32_t(r.u32()); auto error=r.u32();
    v.commit=r.string(); v.preedit=r.string(); v.query=r.string(); v.completion=r.string(); auto message=r.string();
    auto count=r.u32(); require(count<=256,"Too many candidates");
    for(uint32_t i=0;i<count;++i) {
        Candidate c; c.source=r.u8(); c.kind=r.u8(); auto weight=r.u8(), deletable=r.u8();
        require(c.source<=1 && c.kind<=1 && weight<=1 && deletable<=1,"Invalid candidate flags"); c.deletable=deletable;
        for(int j=0;j<4;++j) r.u32(); c.text=r.string(); c.comment=r.string(); v.candidates.push_back(c);
    }
    r.end(); require(v.selected>=-1 && v.selected<int32_t(count),"Invalid candidate selection");
    require(v.page>=0 && v.pages>=0 && (v.pages==0 || v.page<v.pages),"Invalid candidate page");
    if(error) throw std::runtime_error("Engine error: "+message);
    return v;
}
Bytes encodeState(const State &s) {
    Writer w; w.schema(5); w.u8(s.mode); w.u8(s.dictionary); w.u8(s.scheme); w.u8(s.flags);
    w.u32(s.fuzzy); w.u8(s.pageKeys); w.u8(s.completionKey); w.u8(s.pageSize); w.u8(0);
    for(auto &k:s.shortcuts) { w.u16(k.key); w.u8(k.modifiers); w.u8(0); }
    uint8_t disabled=0; for(int i=0;i<5;++i) if(s.shortcuts[i].disabled) disabled|=1<<i;
    w.u8(disabled); w.u8(0); w.u16(0); return w.data;
}
State decodeState(const Bytes &data) {
    Reader r(data); auto schema=r.schema(); require(schema==4 || schema==5,"Unsupported state schema"); State s;
    s.mode=r.u8(); s.dictionary=r.u8(); s.scheme=r.u8(); s.flags=r.u8(); s.fuzzy=r.u32();
    s.pageKeys=r.u8(); s.completionKey=r.u8(); s.pageSize=r.u8(); require(r.u8()==0,"Invalid state flags");
    for(auto &k:s.shortcuts) { k.key=r.u16(); k.modifiers=r.u8(); require(r.u8()==0 && !(k.modifiers&~7),"Invalid shortcut"); }
    if(schema==5) {
        auto mask=r.u8(); require(!(mask&~31) && r.u8()==0 && r.u16()==0,"Invalid shortcut mask");
        for(int i=0;i<5;++i) s.shortcuts[i].disabled=mask&(1<<i);
    }
    r.end(); require(s.mode<=1 && s.dictionary<=1 && s.scheme<=6 && !(s.flags&~15) &&
        s.pageKeys<=3 && s.completionKey<=1 && s.pageSize>=3 && s.pageSize<=9,"Invalid state values");
    return s;
}
void EngineClient::disconnect() { if(fd_>=0) ::close(fd_); fd_=-1; ++generation_; }
bool EngineClient::connect(const std::string &path) {
    disconnect(); sockaddr_un address{}; if(path.size()>=sizeof(address.sun_path)) return false;
    struct stat st{}; if(lstat(path.c_str(),&st) || !S_ISSOCK(st.st_mode) || st.st_uid!=getuid() || (st.st_mode&0077)) return false;
    fd_=socket(AF_UNIX,SOCK_STREAM,0); if(fd_<0) return false;
    fcntl(fd_,F_SETFD,FD_CLOEXEC); fcntl(fd_,F_SETFL,O_NONBLOCK);
    int enabled=1; setsockopt(fd_,SOL_SOCKET,SO_NOSIGPIPE,&enabled,sizeof(enabled));
    address.sun_family=AF_UNIX; address.sun_len=sizeof(address); memcpy(address.sun_path,path.c_str(),path.size()+1);
    if(::connect(fd_,reinterpret_cast<sockaddr *>(&address),sizeof(address))!=0) { disconnect(); return false; }
    try { transact(5,{}); return true; } catch(...) { disconnect(); return false; }
}
static void transfer(int fd, uint8_t *data, size_t size, bool sending,
                     std::chrono::steady_clock::time_point deadline) {
    while(size) {
        auto now=std::chrono::steady_clock::now(); require(now<deadline,"Engine request timed out");
        auto wait=std::chrono::duration_cast<std::chrono::milliseconds>(deadline-now).count();
        pollfd p{fd,short(sending?POLLOUT:POLLIN),0}; int n=::poll(&p,1,int(std::max<int64_t>(1,wait)));
        if(n<0 && errno==EINTR) continue;
        require(n>0 && !(p.revents&(POLLERR|POLLNVAL)),"Engine connection unavailable");
        auto count = sending ? ::send(fd,data,size,0) : ::recv(fd,data,size,0);
        if(count<0 && (errno==EINTR || errno==EAGAIN)) continue;
        require(count>0,"Engine disconnected"); data+=count; size-=size_t(count);
    }
}
Bytes EngineClient::transact(uint16_t type,const Bytes &payload,int timeoutMs) {
    require(fd_>=0,"Engine is not ready");
    try {
        uint64_t id=++request_;
        if(type!=12 && type!=17) ++generation_;
        uint64_t generation=generation_; Writer w;
        w.u32(0x4d495343); w.u16(1); w.u16(0); w.u16(type); w.u16(0); w.u32(0);
        w.u64(id); w.u64(1); w.u64(generation); w.u32(uint32_t(payload.size()));
        w.data.insert(w.data.end(),payload.begin(),payload.end());
        auto deadline=std::chrono::steady_clock::now()+std::chrono::milliseconds(timeoutMs);
        transfer(fd_,w.data.data(),w.data.size(),true,deadline);
        Bytes head(44); transfer(fd_,head.data(),head.size(),false,deadline); Reader r(head);
        require(r.u32()==0x4d495343 && r.u16()==1 && r.u16()==0,"Invalid IPC header"); auto kind=r.u16();
        require(r.u16()==0,"Invalid IPC header flags"); auto flags=r.u32();
        require(flags==1 || flags==3,"Invalid IPC response flags");
        require(r.u64()==id && r.u64()==1 && r.u64()==generation,"Stale IPC response");
        size_t n=r.u32(); require(n<=maxPayload,"IPC response too large"); Bytes reply(n);
        transfer(fd_,reply.data(),reply.size(),false,deadline);
        if(flags&2) { Reader e(reply); require(e.schema()==1,"Invalid engine error"); e.u32(); throw std::runtime_error(e.string()); }
        require(kind==((type==10 || type==17 || type==18)?11:type),"Unexpected IPC response");
        return reply;
    } catch(...) { disconnect(); throw; }
}
void EngineClient::active(bool v) { Writer w; w.schema(); w.u8(v); transact(8,w.data); }
void EngineClient::reset() { transact(7,{}); }
void EngineClient::surrounding(const std::string &s,int32_t c) { Writer w; w.schema(); w.u32(uint32_t(c)); w.string(s); transact(9,w.data); }
Result EngineClient::key(const Key &k) {
    try { return decodeResult(transact(10,encodeKey(k))); } catch(...) { disconnect();throw; }
}
Result EngineClient::poll() {
    try { return decodeResult(transact(17,{})); } catch(...) { disconnect();throw; }
}
State EngineClient::state() {
    try { return decodeState(transact(12,{})); } catch(...) { disconnect();throw; }
}
Result EngineClient::removeCandidate(int32_t index,const std::string &query,const Candidate &expected) {
    Writer w; w.schema(); w.u32(uint32_t(index)); w.string(query); w.string(expected.text); w.string(expected.comment);
    try { return decodeResult(transact(18,w.data)); } catch(...) { disconnect();throw; }
}
void EngineClient::setState(const State &s) { transact(13,encodeState(s)); }
void EngineClient::clearLearning() { transact(16,{}); }
}
