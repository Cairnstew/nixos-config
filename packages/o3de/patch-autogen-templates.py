#!/usr/bin/env python3
"""Create AutoGen Jinja2 template files for all modules that use AUTOGEN_RULES.

These templates are normally downloaded from O3DE's CDN. We create minimal
stubs so AutoGen can generate valid C++ code from the XML input files.
"""
import os, re, sys

py = sys.argv[1] if len(sys.argv) > 1 else 'python3'

# Find all _files.cmake files that reference .jinja templates.
# Only use _files.cmake entries (they have the correct relative paths).
source_root = "."

jinja_refs = []
for root, dirs, files in os.walk(source_root):
    for f in files:
        if not f.endswith('_files.cmake'):
            continue
        path = os.path.join(root, f)
        with open(path) as fh:
            for line in fh:
                m = re.search(r'(\S+\.jinja)', line)
                if m:
                    jinja_refs.append((root, m.group(1)))

# Create template files at the expected paths
templates_created = set()
for root, tmpl in jinja_refs:
    tmpl_path = os.path.join(root, tmpl)
    if tmpl_path in templates_created:
        continue
    if os.path.exists(tmpl_path):
        continue
    templates_created.add(tmpl_path)
    os.makedirs(os.path.dirname(tmpl_path), exist_ok=True)
    
    # Generate appropriate template content based on the template name
    tmpl_name = os.path.basename(tmpl)
    
    if 'Packets_Header' in tmpl_name or 'AutoPackets_Header' in tmpl_name:
        content = '''\
#pragma once
#include <AzNetworking/PacketLayer/IPacket.h>
#include <AzNetworking/Serialization/ISerializer.h>
{% set groupName = dataFiles[0].getroot().attrib['Name'] %}
{% set packetStart = dataFiles[0].getroot().attrib['PacketStart'] | int %}
namespace {{ groupName }} {
enum class PacketType : AzNetworking::PacketType {
{% for packet in dataFiles[0].getroot() %}
    {{ packet.attrib['Name'] }} = {{ packetStart + loop.index0 }},
{% endfor %}
    MAX = {{ packetStart + dataFiles[0].getroot()|length }},
    None = {{ packetStart }}
};
const char* GetPacketString(PacketType packetType);
template <typename TYPE>
class Packet : public AzNetworking::IPacket {
public:
    using PacketTypeEnum = PacketType;
    Packet() = default;
    AzNetworking::PacketType GetPacketType() const override { return static_cast<AzNetworking::PacketType>(TYPE::Type()); }
    bool Serialize(AzNetworking::ISerializer& serializer) override;
};
{% for packet in dataFiles[0].getroot() %}
class {{ packet.attrib['Name'] }} : public Packet<{{ packet.attrib['Name'] }}>
{
public:
    static constexpr PacketTypeEnum TypeEnum = PacketType::{{ packet.attrib['Name'] }};
    static AzNetworking::PacketType Type() { return static_cast<AzNetworking::PacketType>(PacketType::{{ packet.attrib['Name'] }}); }
    AzNetworking::PacketType GetPacketType() const override { return Type(); }
    bool Serialize(AzNetworking::ISerializer& serializer) override;
{% for member in packet %}
    {{ member.attrib['Type'] }} m_{{ member.attrib['Name'] }}{% if member.attrib.get('Init') %} = {{ member.attrib['Init'] }}{% endif %};
{% endfor %}
};
{% endfor %}
}'''
    elif 'Packets_Source' in tmpl_name or 'AutoPackets_Source' in tmpl_name:
        content = '''\
{% set groupName = dataFiles[0].getroot().attrib['Name'] %}
#include <{{ autogenTargetName }}/AutoGen/{{ filename }}.h>
namespace {{ groupName }} {
const char* GetPacketString(PacketType packetType) {
    switch (packetType) {
{% for packet in dataFiles[0].getroot() %}
    case PacketType::{{ packet.attrib['Name'] }}: return "{{ packet.attrib['Name'] }}";
{% endfor %}
    default: return "Unknown";
    }
}
template <typename TYPE>
bool Packet<TYPE>::Serialize(AzNetworking::ISerializer& serializer) { return true; }
{% for packet in dataFiles[0].getroot() %}
bool {{ packet.attrib['Name'] }}::Serialize(AzNetworking::ISerializer& serializer) {
    bool result = true;
{% for member in packet %}
    result &= serializer.Serialize(m_{{ member.attrib['Name'] }}, "{{ member.attrib['Name'] }}");
{% endfor %}
    return result && Packet<{{ packet.attrib['Name'] }}>::Serialize(serializer);
}
{% endfor %}
}'''
    elif 'Packets_Inline' in tmpl_name or 'AutoPackets_Inline' in tmpl_name:
        content = ''
    elif 'PacketDispatcher_Header' in tmpl_name:
        content = '''\
#pragma once
{% set groupName = dataFiles[0].getroot().attrib['Name'] %}
#include <{{ autogenTargetName }}/AutoGen/{{ filename }}.h>
namespace {{ groupName }} {
template <typename HANDLER>
class PacketDispatcher {
public:
    using PacketTypeEnum = PacketType;
    bool DispatchPacket(HANDLER& handler, AzNetworking::IPacket& packet, AzNetworking::IConnection* connection);
};
}'''
    elif 'PacketDispatcher_Inline' in tmpl_name:
        content = ''
    elif 'AutoComponent_Header' in tmpl_name:
        content = '''\
#pragma once
{% for dataFile in dataFiles %}
{% set ComponentName = dataFile.getroot().attrib['Name'] %}
#include <AzCore/Component/Component.h>
namespace {{ ComponentName }} {
class {{ ComponentName }}Config : public AZ::ComponentConfig {
public:
    AZ_RTTI({{ ComponentName }}Config, "{00000000-0000-0000-0000-000000000000}", AZ::ComponentConfig);
    bool Serialize(AzNetworking::ISerializer& serializer) { return true; }
};
class {{ ComponentName }}Component : public AZ::Component {
public:
    AZ_COMPONENT({{ ComponentName }}Component, "{00000000-0000-0000-0000-000000000000}", AZ::Component);
    static void Reflect(AZ::ReflectContext* context) {}
    void Activate() override {}
    void Deactivate() override {}
    static void GetRequiredServices(AZ::ComponentDescriptor::DependencyArrayType& required) {}
    static void GetProvidedServices(AZ::ComponentDescriptor::DependencyArrayType& provided) {}
};
}'''
    elif 'AutoComponent_Source' in tmpl_name:
        content = '''\
{% for dataFile in dataFiles %}
{% set ComponentName = dataFile.getroot().attrib['Name'] %}
#include <{{ autogenTargetName }}/AutoGen/{{ filename }}.h>
{% endfor %}'''
    else:
        content = ''
    
    with open(tmpl_path, 'w') as f:
        f.write(content)
    print(f"Created template: {tmpl_path}")

print(f"Created {len(templates_created)} AutoGen templates")
