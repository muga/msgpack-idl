#
# MessagePack IDL Processor
#
# Copyright (C) 2011 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module Example
	LIST = []

	def self.list
		LIST
	end

	def self.get(name)
		n, summary, code = LIST.find {|n, summary, code|
			name == n
		}
		unless code
			raise "unknown example name: #{name}"
		end
		result = "# #{name} - #{summary} example\n"
		result << code
		result
	end

	def self.add(name, summary, code)
		LIST << [name, summary, code]
	end

	add 'syntax', 'basic syntax', <<EOF

# this is a comment
// this is a comment

/*
this is also a comment
*/

# namespace declaration
#   java: this becomes the package name
namespace com.example

# message type declaration
message MessageName {
    # <id>: ["optional"] <type> <name> [= <initial value>]
    1: map<string,string> property
    2: optional string name
}

# include other files
include sample.msgspec
EOF

	add 'types', 'basic types', <<EOF
namespace com.example

message BasicTypeExample {
    1:  byte   f1    # signed 8-bit integer
    2:  short  f2    # signed 16-bit integer
    3:  int    f3    # signed 32-bit integer
    4:  long   f4    # signed 64-bit integer
    5:  ubyte  f5    # unsigned 8-bit integer
    6:  ushort f6    # unsigned 16-bit integer
    7:  uint   f7    # unsigned 32-bit integer
    8:  ulong  f8    # unsigned 64-bit integer
    9:  float  f9    # single precision float
    10: double f10   # double precision float
    11: bool   f11   # boolean
    12: raw    f12   # raw bytes
    13: string f13   # string
}

message ContainerTypeExample {
    1: list<string> f1                # list
    2: map<string,int> f2             # map
    2: map<string, list<string>> f2   # nesting is ok
}
EOF

	add 'optional', 'optional fields', <<EOF
namespace com.example

message OptionalExample {
    1: int f1              # required field
    2: required int f1     # required field
    3: optional int f2     # optional field

    4: int? f1             # required nullable field
    5: required int? f1    # required nullable field
    6: optional int? f2    # optional nullable field
}
EOF

	add 'enum', 'enum definition', <<EOF
enum EnumExcample {
    0: RED
    1: GREEN
    2: BLUE
}
EOF

	add 'sample', 'simple sample', <<EOF
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
EOF

	add 'service', 'simple rpc', <<EOF
exception DiskError {
    1: string message
}

service PropertyStoreService {
    raw? get(1: raw key)
    void set(1: raw key, 2: raw value) throws DiskError
}
EOF

	add 'version', 'versioned rpc', <<EOF
exception DiskError {
    1: string message
}

service PropertyStoreService:0 {
    void set(1: raw key, 2: raw value)
    raw? get(1: raw key)
}

service PropertyStoreService:1 {
    void set(1: raw key, 2: raw value) throws DiskError

    # inherit former version's function
    inherit get
}

service PropertyStoreService:2 {
    void set(1: raw key, 2: raw value, 3: int flags) throws DiskError

    # type-checked inheritance
    inherit raw? get(1: raw key)

    int? getFlags(1: raw key)
}

service PropertyStoreService:3 {
    # inherit all functions
    inherit *
}
EOF

	add 'application', 'multi-namespace rpc', <<EOF
service KeyValueService:0 {
    void set(1: raw key, 2: raw value)
    raw? get(1: raw key)
}

service CacheService:0 {
    void set(1: raw key, 2: raw value, 3: long expire)
    raw? get(1: raw key)
}

application MyApp {
    KeyValueService:0 kv default
    CacheService:0 cache
}
EOF

end

