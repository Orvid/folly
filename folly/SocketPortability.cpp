/*
* Copyright 2015 Facebook, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

#ifdef _MSC_VER
#include <folly/SocketPortability.h>

namespace folly { namespace socket_portability {

namespace {
  // We have to startup WSA.
  struct FSPInit {
    FSPInit() {
      WSADATA dat;
      WSAStartup(MAKEWORD(2, 2), &dat);
    }
    ~FSPInit() {
      WSACleanup();
    }
  };
  static FSPInit fspInit;
}

SOCKET fd_to_socket(int fd) {
  // We do this in a roundabout way to enable us to
  // do a bit of trickery to ensure that things aren't
  // being implicitly converted to a SOCKET by temporarily
  // adjusting the windows headers to define SOCKET as a
  // structure.
  HANDLE tmp = (HANDLE)_get_osfhandle(fd);
  return *(SOCKET*)&tmp;
}

int socket_to_fd(SOCKET s) {
  return _open_osfhandle((intptr_t)s, O_RDWR | O_BINARY);
}

template<class R, class F, class... Args>
R wrapSocketFunction(F f, int s, Args... args) {
  SOCKET h = fd_to_socket(s);
  R ret = f(h, args...);
  errno = WSAGetLastError();
  return ret;
}

int accept(int s, struct sockaddr* addr, socklen_t* addrlen) {
  return socket_to_fd(wrapSocketFunction<SOCKET>(::accept, s, addr, addrlen));
}

int bind(int s, const struct sockaddr* name, socklen_t namelen) {
  return wrapSocketFunction<int>(::bind, s, name, namelen);
}

int connect(int s, const struct sockaddr* name, socklen_t namelen) {
  return wrapSocketFunction<int>(::connect, s, name, namelen);
}

int getpeername(int s, struct sockaddr* name, socklen_t* namelen) {
  return wrapSocketFunction<int>(::getpeername, s, name, namelen);
}

int getsockname(int s, struct sockaddr* name, socklen_t* namelen) {
  return wrapSocketFunction<int>(::getsockname, s, name, namelen);
}

int getsockopt(int s, int level, int optname, char* optval, socklen_t* optlen) {
  return wrapSocketFunction<int>(::getsockopt, s, level,
                                 optname, (char*)optval, optlen);
}

int getsockopt(int s, int level, int optname, void* optval, socklen_t* optlen) {
  return wrapSocketFunction<int>(::getsockopt, s, level,
                                 optname, (char*)optval, optlen);
}

int inet_aton(const char *cp, struct in_addr *inp) {
  inp->s_addr = inet_addr(cp);
  return inp->s_addr == INADDR_NONE ? 0 : 1;
}

const char* inet_ntop(int af, const void* src, char* dst, socklen_t size) {
  return ::inet_ntop(af, (char*)src, dst, size);
}

int listen(int s, int backlog) {
  return wrapSocketFunction<int>(::listen, s, backlog);
}

int poll(pollfd* fds, nfds_t nfds, int timeout) {
  for (int i = 0; i < nfds; i++) {
    fds[i].fd = fd_to_socket(fds[i].fd);
  }
  return ::WSAPoll(fds, (ULONG)nfds, timeout);

  // Below is a, currently non-functional, attempt at
  // supporting a mix of file descriptors and sockets.
  /*
  pollfd* newFds = (pollfd*)calloc(nfds, sizeof(pollfd));
  int newFdsCnt = 0;

  ULONGLONG limit;
  HANDLE handles[MAXIMUM_WAIT_OBJECTS];
  int n_handles = 0;

  // build an array of handles for non-sockets
  for (int i = 0; i < nfds; i++) {
    if (file_portability::is_fh_socket(fds[i].fd)) {
      newFds[newFdsCnt] = fds[i];
      newFds[newFdsCnt++].fd = fd_to_socket(fds[i].fd);
    } else {
      handles[n_handles++] = (HANDLE)_get_osfhandle(fds[i].fd);
    }
  }

  //if (n_handles == 0) {
    free(newFds);
    // plain sockets only - let winsock handle the whole thing
    return ::WSAPoll(fds, (ULONG)nfds, timeout);
  //}

  // mixture of handles and sockets; lets multiplex between
  // winsock and waiting on the handles

  int retcode = 0;
  limit = GetTickCount64() + timeout;
  do {
    retcode = 0;

    if (newFdsCnt > 0) {
      // overwrite the zero'd sets here; the select call
      // will clear those that are not active

      retcode = ::WSAPoll(newFds, (ULONG)newFdsCnt, timeout);
    }
    if (n_handles > 0) {
      // check handles
      DWORD wret;

      wret = MsgWaitForMultipleObjects(n_handles, handles, FALSE,
                                        retcode > 0 ? 0 : 100, QS_ALLEVENTS);

      if (wret == WAIT_TIMEOUT) {
        // set retcode to 0; this is the default.
        // select() may have set it to something else,
        // in which case we leave it alone, so this branch
        // does nothing
        ;
      } else if (wret == WAIT_FAILED) {
        if (retcode == 0) {
          retcode = -1;
        }
      } else {
        if (retcode < 0) {
          retcode = 0;
        }
        for (int i = 0; i < n_handles; i++) {
          if (WAIT_OBJECT_0 == WaitForSingleObject(handles[i], 0)) {
            retcode++;
          }
        }
      }
    }
  } while (retcode == 0 && (timeout == INFINITE || GetTickCount64() < limit));

  free(newFds);
  return retcode;
  */
}

int recv(int s, char* buf, int len, int flags) {
  return wrapSocketFunction<int>(::recv, s, (char*)buf, len, flags);
}

int recv(int s, void* buf, int len, int flags) {
  return wrapSocketFunction<int>(::recv, s, (char*)buf, len, flags);
}

int recvfrom(int s, char* buf, int len,
              int flags, struct sockaddr* from, socklen_t* fromlen) {
  return wrapSocketFunction<int>(::recvfrom, s, (char*)buf, len,
                                 flags, from, fromlen);
}

int recvfrom(int s, void* buf, int len,
              int flags, struct sockaddr* from, socklen_t* fromlen) {
  return wrapSocketFunction<int>(::recvfrom, s, (char*)buf, len,
                                 flags, from, fromlen);
}

ssize_t recvmsg(int s, struct msghdr* message, int fl) {
  SOCKET h = fd_to_socket(s);

  // Don't currently support the name translation.
  if (message->msg_name != nullptr || message->msg_namelen != 0)
    return (ssize_t)-1;
  WSAMSG msg;
  msg.name = nullptr;
  msg.namelen = 0;
  msg.Control.buf = (CHAR*)message->msg_control;
  msg.Control.len = (ULONG)message->msg_controllen;
  msg.dwFlags = 0;
  msg.dwBufferCount = (DWORD)message->msg_iovlen;
  msg.lpBuffers = new WSABUF[message->msg_iovlen];
  for (size_t i = 0; i < message->msg_iovlen; i++) {
    msg.lpBuffers[i].buf = (CHAR*)message->msg_iov[i].iov_base;
    msg.lpBuffers[i].len = (ULONG)message->msg_iov[i].iov_len;
  }

  LPFN_WSARECVMSG WSARecvMsg;
  GUID WSARecgMsg_GUID = WSAID_WSARECVMSG;
  DWORD recMsgBytes;
  WSAIoctl(h, SIO_GET_EXTENSION_FUNCTION_POINTER,
    &WSARecgMsg_GUID, sizeof(WSARecgMsg_GUID),
    &WSARecvMsg, sizeof(WSARecvMsg),
    &recMsgBytes, nullptr, nullptr);

  DWORD bytesReceived;
  int res = WSARecvMsg(h, &msg, &bytesReceived, nullptr, nullptr);
  delete[] msg.lpBuffers;
  if (res == 0)
    return (ssize_t)bytesReceived;
  return -1;
}

int send(int s, const char* buf, int len, int flags) {
  return wrapSocketFunction<int>(::send, s, (char*)buf, len, flags);
}

int send(int s, const void* buf, int len, int flags) {
  return wrapSocketFunction<int>(::send, s, (char*)buf, len, flags);
}

ssize_t sendmsg(int s, const struct msghdr *message, int fl) {
  SOCKET h = fd_to_socket(s);

  // Don't currently support the name translation.
  if (message->msg_name != nullptr || message->msg_namelen != 0)
    return (ssize_t)-1;
  WSAMSG msg;
  msg.name = nullptr;
  msg.namelen = 0;
  msg.Control.buf = (CHAR*)message->msg_control;
  msg.Control.len = (ULONG)message->msg_controllen;
  msg.dwFlags = 0;
  msg.dwBufferCount = (DWORD)message->msg_iovlen;
  msg.lpBuffers = new WSABUF[message->msg_iovlen];
  for (size_t i = 0; i < message->msg_iovlen; i++) {
    msg.lpBuffers[i].buf = (CHAR*)message->msg_iov[i].iov_base;
    msg.lpBuffers[i].len = (ULONG)message->msg_iov[i].iov_len;
  }

  DWORD bytesSent;
  int res = WSASendMsg(h, &msg, 0, &bytesSent, nullptr, nullptr);
  delete[] msg.lpBuffers;
  if (res == 0)
    return (ssize_t)bytesSent;
  return -1;
}

int sendto(int s, const char* buf, int len, int flags,
           const sockaddr* to, socklen_t tolen) {
  return wrapSocketFunction<int>(::sendto, s, (char*)buf, len, flags,
                                 to, tolen);
}

int sendto(int s, const void* buf, int len, int flags,
           const sockaddr* to, socklen_t tolen) {
  return wrapSocketFunction<int>(::sendto, s, (char*)buf, len, flags,
                                 to, tolen);
}

int setsockopt(int s, int level, int optname,
               const char* optval, socklen_t optlen) {
  return wrapSocketFunction<int>(::setsockopt, s, level,
                                 optname, (char*)optval, optlen);
}

int setsockopt(int s, int level, int optname,
               const void* optval, socklen_t optlen) {
  return wrapSocketFunction<int>(::setsockopt, s, level,
                                 optname, (char*)optval, optlen);
}

int shutdown(int s, int how) {
  return wrapSocketFunction<int>(::shutdown, s, how);
}

int socketpair(int domain, int type, int protocol, int sockot[2]) {
  struct sockaddr_in address;
  SOCKET redirect;
  SOCKET sock[2];
  int size = sizeof(address);

  if (domain != AF_INET) {
    WSASetLastError(WSAENOPROTOOPT);
    return -1;
  }

  sock[0] = sock[1] = redirect = INVALID_SOCKET;

  sock[0] = ::socket(domain, type, protocol);
  if (sock[0] == INVALID_SOCKET)
    goto error;

  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_family = AF_INET;
  address.sin_port = 0;

  if (::bind(sock[0], (struct sockaddr*)&address, sizeof(address)) != 0)
    goto error;
  if (::getsockname(sock[0], (struct sockaddr*)&address, &size) != 0)
    goto error;
  if (::listen(sock[0], 2) != 0)
    goto error;

  sock[1] = ::socket(domain, type, protocol);
  if (sock[1] == INVALID_SOCKET)
    goto error;

  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (::connect(sock[1], (struct sockaddr*)&address, sizeof(address)) != 0)
    goto error;

  redirect = ::accept(sock[0], (struct sockaddr*)&address, &size);
  if (redirect == INVALID_SOCKET)
    goto error;

  ::closesocket(sock[0]);
  sock[0] = redirect;

  sockot[0] = socket_to_fd(sock[0]);
  sockot[1] = socket_to_fd(sock[1]);
  return 0;

error:
  ::closesocket(redirect);
  ::closesocket(sock[0]);
  ::closesocket(sock[1]);
  ::WSASetLastError(WSAECONNABORTED);
  return -1;
}


int socket(int af, int type, int protocol) {
  return socket_to_fd(::socket(af, type, protocol));
}

}}
#endif
