MessagePack IDL Processor
=========================
MessagePack interface definition language processor

## Installation

    $ gem install msgpack-idl
    $ msgpack-idl --install java

# Usage

See help:

    $ msgpack-idl --help

## Example

    namespace com.example
    
    message UserInfo {
        1: int uid
        2: string name
        3: optional int flags = 1
    }
    
    enum Sites {
        0: SiteA
        1: SiteB
        2: SiteC
    }
    
    message LogInLog {
        1: UserInfo user
        2: Sites site
    }


