---
title: "Agent Identity Metadata"
abbrev: "Agent Identity Metadata"
category: std

docname: draft-heigh-wimse-agent-identity-metadata-latest
submissiontype: IETF
number:
date:
consensus: true
v: 3
area: "Security"
workgroup: "Workload Identity in Multi System Environments"
keyword:
 - agent identity
 - workload identity
 - identifier
 - metadata
 - delegation
venue:
  group: "Workload Identity in Multi System Environments"
  type: "Working Group"
  mail: "wimse@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/wimse/"
  github: "szh/draft-agent-identity-metadata"
  latest: "https://szh.github.io/draft-agent-identity-metadata/draft-heigh-wimse-agent-identity-metadata.html"

author:
 -
    ins: S. Heigh
    name: Shlomo Heigh
    organization: Palo Alto Networks
    email: sheigh@paloaltonetworks.com
 -
    ins: J. Salowey
    name: Joseph Salowey
    organization: Palo Alto Networks
    email: joe@salowey.net
 -
    ins: Y. Rosomakho
    name: Yaroslav Rosomakho
    organization: Zscaler
    email: yrosomakho@zscaler.com

normative:
  I-D.ietf-wimse-identifier:
  I-D.ietf-wimse-workload-creds:
  RFC7519:
  RFC7643:
  RFC9068:

informative:
  I-D.ietf-wimse-arch:
  I-D.ietf-wimse-aims:
  RFC5755:
  RFC8693:
  SPIFFE-JWT-SVID:
    title: "SPIFFE JWT-SVID"
    target: "https://github.com/spiffe/spiffe/blob/main/standards/JWT-SVID.md"
    author:
      - org: "SPIFFE Project"
  SPIFFE-X509-SVID:
    title: "SPIFFE X.509-SVID"
    target: "https://github.com/spiffe/spiffe/blob/main/standards/X509-SVID.md"
    author:
      - org: "SPIFFE Project"

...

--- abstract

This document specifies metadata attributes associated with an AI agent's identity that are used for
auditing, authorization, accounting and other purposes. It specifies how to carry these attributes within
WIMSE credentials such as a JWT-based Workload Identity Token (WIT) or an X.509-based Workload Identity
Certificate (WIC). Those attributes include groups the agent belongs to, the roles it performs, and the
human principal it acts on behalf of.

This document defines the separation between identifier and metadata, and profiles existing claims for
expressing agent group, role, and associated human identity. It distinguishes an agent's attributes
from grants such as scopes, and states the requirements that make the separation sound, including
identifier uniqueness.

--- middle

# Introduction {#intro}

An identifier denotes an agent. Metadata describes it. These are different things with different
lifetimes, different authorities, and different exposure, and conflating them causes concrete harm.

Encoding them in the identifier is common practice, but it produces identifiers with structured paths
that relying parties are then expected to parse and authorize on. Deployments that need to authorize
on an agent's group, role, or
human owner frequently encode those attributes into the identifier, producing identifiers of the form:

~~~
spiffe://example.com/ns/prod/team/payments/role/admin/agent/reconciler
~~~

Relying parties are then expected to parse path components and authorize on them. This appears to
work, and it is the path of least resistance because the identifier is the one field guaranteed to
reach the relying party. It is nonetheless unsound, for reasons developed in {{pollution}}: the
identifier format does not promise parseable semantics, attributes and identifiers have different
lifetimes, and the identifier is the most widely exposed field in the system.

This document specifies the alternative. An identifier denotes exactly one agent and carries no
semantics a relying party may rely on. Everything a deployment needs to know about the agent travels
as metadata in the Identity Credential that asserts the identifier: a JWT such as a WIMSE Workload
Identity Token {{I-D.ietf-wimse-workload-creds}} or a JWT-SVID, or an X.509 certificate.

Where suitable claims already exist, this document profiles them rather than defining new ones. Group,
role, and entitlement claims are already registered {{RFC9068}} with semantics drawn from SCIM
{{RFC7643}}, and delegation is already expressible {{RFC8693}}.

## Scope

In scope:

* the separation between identifier and metadata, and requirements enforcing it;
* metadata for agent group, role, and associated human principal;
* how metadata is carried in JWT-based and X.509-based identity credentials;
* the identifier uniqueness requirements that the separation depends on.

Out of scope:

* the identifier format itself, which is {{I-D.ietf-wimse-identifier}};
* authentication and transport protocols;
* how a relying party reaches an authorization decision from metadata;
* verification of the identity credentials, for which see
  {{Section 3 of I-D.ietf-wimse-workload-creds}}, {{SPIFFE-JWT-SVID}}, and {{SPIFFE-X509-SVID}}.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

Logical Agent:
: An AI agent considered as a unit of authorization and audit. Two agents are distinct Logical Agents
  if a deployment intends them to be separately authorized, separately revocable, or separately
  attributable in an audit record.

Execution Instance:
: A single running process, container, task, or session executing a Logical Agent. One Logical Agent
  may have many concurrent Execution Instances.

Agent Identifier:
: A Workload Identifier, as defined in {{I-D.ietf-wimse-identifier}}, that denotes a Logical Agent.

Identity Credential:
: A signed object asserting an Agent Identifier. In WIMSE deployments this is a Workload Identity Token
  (WIT) or a Workload Identity Certificate (WIC), both defined in {{I-D.ietf-wimse-workload-creds}}.
  The term is used here to cover both, and to cover equivalents such as the SPIFFE JWT-SVID
  {{SPIFFE-JWT-SVID}} and X.509-SVID {{SPIFFE-X509-SVID}}. Identity Credentials are also sometimes
  referred to as identity documents.

Agent Metadata:
: Attributes of a Logical Agent conveyed in an Identity Credential, distinct from the Agent Identifier.

Issuer:
: The entity that assigns an Agent Identifier, determines Agent Metadata, and issues the Identity
  Credential asserting them.

# The Separation Principle {#separation}

## Why Attributes Are Not Encoded in Identifiers {#pollution}

The reasons below are independent: a solution that mitigates one still faces the others.

Path semantics are not guaranteed.
: {{Section 4.2 of I-D.ietf-wimse-identifier}} states that path contents are "deployment-specific and
  are interpreted according to the scheme, policy of the trust domain, as implemented by the issuer or
  issuers authorized for that trust domain", and {{Section 4.3 of I-D.ietf-wimse-identifier}} requires
  that consumers "MUST compare and authorize Workload Identifiers using the complete URI, rather than
  relying only on individual components such as the path". A relying party parsing path components to
  recover a role is doing something the identifier format does not support.

Lifetimes differ.
: An Agent Identifier is stable; it is the thing audit records and authorization grants refer to over
  time. Attributes are mutable: an agent is reassigned to another team, its role narrows, its human
  owner leaves. Encoding a mutable attribute in a stable identifier forces a choice between two bad
  outcomes. Re-identifying the agent whenever an attribute changes breaks every grant and every
  historical audit record that named it. Leaving the identifier alone lets it assert something that is
  no longer true.

Cardinality multiplies.
: Encoding *n* attributes produces an identifier space that is their cross product. Every combination
  of group, role, and owner becomes a distinct identifier requiring its own registration, its own
  grants, and its own policy entries.

Authorization becomes string matching.
: Policy written against path prefixes couples authorization to a naming convention. Renaming a team
  silently changes who is authorized, and the coupling is invisible at both the policy and the naming
  end. {{Section 7.6 of I-D.ietf-wimse-identifier}} advises consumers against exactly this, warning
  that prefix matching "may lead to incorrect authorization".

Exposure is maximal.
: The identifier is the most widely visible field in the system. It appears in audit logs across every
  component on the call path, in certificate subject alternative names transmitted during TLS
  handshakes, and in diagnostic output. Attributes embedded there are disclosed wherever the
  identifier travels, which is everywhere. {{Section 7.5 of I-D.ietf-wimse-identifier}} raises the
  same concern for descriptive paths generally. It is most acute for human identity; see {{privacy}}.

Authority differs.
: The authority competent to assign an identifier is not necessarily the authority competent to assert
  a role or a human association. Encoding both in one string requires a single issuer to be
  authoritative for all of it.

WIMSE has already applied this reasoning to a narrower case.
{{Section 4 of I-D.ietf-wimse-workload-creds}} requires that where a deployment has several labels for
one runtime, additional correlation "MUST NOT be encoded as a second workload identifier", directing
deployments to additional claims instead. This document generalizes that reasoning from correlation data
to agent attributes.

PKIX addressed the same tension earlier, separating attributes from identity certificates into attribute
certificates {{RFC5755}}. The mechanism saw limited deployment, but the analysis holds and the
separation it describes is the one specified here.

## Content of the Agent Identifier {#identifier-role}

An Agent Identifier MUST denote exactly one Logical Agent, and a relying party MUST NOT rely on it for
any purpose other than denoting that agent. A relying party requiring an agent's group, role, human
association, or permissions therefore MUST obtain it from Agent Metadata.

An Issuer MAY use structured paths for administrative convenience, such as delegation of naming
authority within a trust domain or operator legibility. Where it does, the structure is not a contract: a
relying party MUST NOT derive authorization-relevant meaning from any component of an Agent
Identifier.

## Content of the Identity Credential {#document-role}

An Identity Credential asserts an Agent Identifier and MAY assert Agent Metadata describing the Logical
Agent that identifier denotes. Metadata in an Identity Credential is asserted by the Issuer and inherits
the Credential's signature, its validity period, and its trust path. That is what distinguishes it from
an attribute the agent asserts about itself at the application layer.

# Agent Metadata {#metadata}

## Reuse of Existing Claims {#reuse}

This document does not define new claims for group, role, or permission where registered claims exist.
{{Section 7.2.1 of RFC9068}} registers `groups`, `roles`, and `entitlements` in the JSON Web Token
Claims registry, referring for their definitions to {{Section 4.1.2 of RFC7643}}. An Identity Credential
expressing an agent's group, role, or entitlements MUST use those claims.

| Attribute | Claim | Source |
|---|---|---|
| Group membership | `groups` | {{RFC9068}}, {{RFC7643}} |
| Role | `roles` | {{RFC9068}}, {{RFC7643}} |
| Coarse entitlements | `entitlements` | {{RFC9068}}, {{RFC7643}} |
| Associated human principal | see {{human}} | {{RFC8693}} |

Two aspects of this reuse need stating explicitly.

The subject is the agent.
: {{Section 2.2.3.1 of RFC9068}} motivates these claims in terms of the resource owner, citing
  "resource owner memberships in roles and groups" and "entitlements assigned to the resource owner",
  and {{RFC7643}} defines them as attributes of a SCIM `User`. This document applies them to the subject of
  the Identity Credential, which is an agent rather than a person. The registrations themselves are
  subject-neutral, so no conflict arises, but a relying party MUST interpret these claims as describing
  the Logical Agent denoted by `sub` and MUST NOT interpret them as describing the human principal of
  {{human}}, where one is asserted.

Value encoding is not fully determined.
: {{RFC7643}} specifies no vocabulary or syntax for `roles` and `entitlements`, expecting a role value
  to be "a String or label representing a collection of entitlements". It describes `groups`
  differently: as a multi-valued complex attribute with `value` and `type` sub-attributes and canonical
  types "direct" and "indirect", derived from SCIM `Group` resources that have no counterpart here.
  Neither {{RFC9068}} nor this document settles whether `groups` in an Identity Credential is an array of
  strings or an array of objects. Until it is settled, an Issuer SHOULD encode all three claims as
  arrays of strings, and a relying party SHOULD accept an array of objects bearing a `value`
  sub-attribute as equivalent to the array of those `value` strings. See {{open-issues}} item 3.

Values are otherwise trust-domain specific, and this document defines no vocabulary. A relying party
MUST treat an unrecognized value as conveying no authority rather than as a wildcard.

## Associated Human Principal {#human}

An agent frequently acts on behalf of a human principal, and deployments need that association for
authorization and for attribution. Existing WIMSE work already determines where most of it belongs.

The Identity Credential's `sub` is the agent.
: {{Section 4 of I-D.ietf-wimse-workload-creds}} requires that each credential carry exactly one
  Workload Identifier, and that "for a Workload Identity Token, that identifier is the value of the sub
  claim". A human principal therefore cannot occupy `sub`. This document imposes no additional
  requirement here; it relies on that one.

Per-request delegation belongs to the access token.
: {{Section 10.3 of I-D.ietf-wimse-aims}} places the agent's identity in the access token's `client_id`
  and, "when the Agent is acting on-behalf of another User or System", that party's identifier in the
  access token's `sub`. The access token, not the Identity Credential, therefore carries the
  on-behalf-of relationship, alongside the scopes it authorizes.

This resolves the apparent conflict with {{RFC8693}}, whose `act` claim identifies "the acting party to
whom authority has been delegated" and which would otherwise place the human in `sub`. There is no
conflict, because there are two credentials: the Identity Credential says which agent this is, and the
access token says on whose behalf and for what it is presently authorized.

Applying the distinction of {{permissions}}, the per-request "acting on behalf of" relationship is a
grant and does not belong in an Identity Credential. What remains genuinely open is whether a durable
association, meaning that an agent was provisioned for and is permanently attributable to a particular
person, is an attribute of the agent worth asserting at issuance. It has the stability of an attribute
and, unlike a scope, does not express authority. This document does not yet take a position; see
{{open-issues}} item 1.

An Identity Credential asserting a human principal makes a claim about a person and is subject to
{{privacy}}.

## Permissions and Scopes {#permissions}

Deployments frequently want an agent's permissions in its Identity Credential. This document
distinguishes two cases and treats them differently, because they are not the same kind of statement.

Attributes of the subject, such as group, role, and coarse entitlements, describe what the agent is. They are
relatively stable, they are meaningful independent of any particular relying party, and the Issuer is
plausibly authoritative for them. These belong in the Identity Credential per {{reuse}}.

Grants, such as scopes and fine-grained permissions, describe what the agent may do at a given resource at a
given moment. They are relationship-specific, they change faster than an identity credential's lifetime,
and the authority for them is the resource owner or an authorization server, not the identity issuer.

Accordingly, an Identity Credential MAY carry coarse entitlements per {{reuse}}, but SHOULD NOT carry
resource-specific scopes or fine-grained permissions. Where a deployment carries them anyway, a relying
party MUST NOT treat them as authoritative for an authorization decision, and MUST obtain authorization
from its own policy or from an authorization server. {{capability}} gives the reasoning.

## Identifier Uniqueness {#uniqueness}

The separation principle depends on the identifier actually denoting one agent. Where an identifier is
shared, metadata cannot restore the distinction: a relying party receiving a shared identifier with
agent-specific metadata has no way to establish that the metadata describes the agent that is calling
rather than a co-tenant.

Existing work establishes the requirement. {{Section 6 of I-D.ietf-wimse-aims}} requires that an agent
"MUST be assigned exactly one WIMSE identifier"; {{Section 4.3 of I-D.ietf-wimse-identifier}} requires
that issuers "MUST ensure uniqueness of all Workload Identifiers they assign"; and
{{Section 4.5 of I-D.ietf-wimse-identifier}} and {{Section 7.4 of I-D.ietf-wimse-identifier}} advise
against reassigning a retired identifier. Sharing is permitted only where the instances "are intended to
be treated as the same workload for the purpose of authentication, authorization, and auditing"
({{Section 4.2 of I-D.ietf-wimse-identifier}}). Multiple Execution Instances of one Logical Agent
satisfy that condition; distinct Logical Agents sharing an execution environment do not.

What none of these address is the case that makes the requirement hard to meet in practice: platforms
commonly issue a credential scoped to the execution environment rather than to the agent, such as an
execution role assumed by every agent in a deployment, so the only subject available to an Issuer is one
shared by several Logical Agents. Therefore:

An Issuer MUST NOT use the subject of a platform-provided execution credential as an Agent Identifier
where that credential is, or may become, available to more than one Logical Agent.

Where the platform offers only such a credential, an Issuer MUST establish by a means not under the
control of the agent which Logical Agent a requesting Execution Instance is executing, and MUST issue
an Identity Credential asserting an Agent Identifier denoting that agent rather than passing the
execution credential through. The execution credential MAY be an input to that determination as
evidence of the execution environment; it MUST NOT be the sole input.

# Carrying Metadata in Identity Credentials {#carriage}

## JWT-Based credentials {#jwt}

Metadata is carried as claims in the JWT {{RFC7519}} claims set, using the claims in {{reuse}}. No new
mechanism is required, and the rules for doing so are already established:
{{Section 5.1.2 of I-D.ietf-wimse-workload-creds}} permits additional claims in a WIT, requires that a
recipient ignore claims it does not understand, discourages private claim names, and requires that
claims used outside closed environments be registered with IANA. Because the claims in {{reuse}} are
already registered, an Identity Credential expressing agent group, role, or entitlements satisfies those
rules without further action.

The following non-normative examples show Identity Credentials for the agent that {{intro}} names with an
attribute-bearing identifier. In each, the identifier is opaque and the attributes appear only as claims.

A WIT, whose JOSE header carries `"typ": "wit+jwt"`:

~~~ json
{
  "iss": "https://issuer.example.com",
  "sub": "wimse://example.com/agent/a7f3c1a24b904d61",
  "iat": 1757894400,
  "exp": 1757898000,
  "jti": "e1f0c7d2a9b34c58",
  "cnf": {
    "jwk": {
      "alg": "ES256", "kty": "EC", "crv": "P-256",
      "x": "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
      "y": "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0"
    }
  },
  "groups": ["team-payments"],
  "roles": ["reconciler"],
  "entitlements": ["ledger-read"]
}
~~~

The `cnf` claim is mandatory in a WIT and binds the credential to the workload's key; a WIT has no `aud`
claim and cannot be used as a bearer token
({{Section 5.1 of I-D.ietf-wimse-workload-creds}}). The same agent as a JWT-SVID {{SPIFFE-JWT-SVID}},
which is instead audience-restricted and carries no confirmation claim:

~~~ json
{
  "sub": "spiffe://example.com/agent/a7f3c1a24b904d61",
  "aud": ["spiffe://example.com/service/ledger"],
  "iat": 1757894400,
  "exp": 1757898000,
  "groups": ["team-payments"],
  "roles": ["reconciler"],
  "entitlements": ["ledger-read"]
}
~~~

The metadata is identical across the two formats, as {{consistency}} requires. Two properties of these
examples illustrate what the separation buys. Reassigning the agent to another team
changes `groups` and leaves `sub` untouched, so every existing grant and every historical audit record
that named the agent remains valid and remains accurate. And a relying party that is not authorized to
learn the agent's role can be issued a credential omitting `roles`, without changing the agent's
identity, because the identifier no longer carries it.

## X.509-Based credentials {#x509}

X.509 certificates have no equivalent of a claims set, so carrying metadata in one requires a mechanism
this document does not yet specify.

{{Section 6.1 of I-D.ietf-wimse-workload-creds}} defines the Workload Identity Certificate, which
carries the Workload Identifier in a single URI SubjectAltName. The obvious approach is therefore
already closed: {{Section 4 of I-D.ietf-wimse-workload-creds}} requires that additional correlation
"MUST NOT be encoded as a second workload identifier in the same WIT or WIC", so agent attributes cannot
be carried in a second URI SAN. For an X.509-SVID the constraint is stronger still:
{{SPIFFE-X509-SVID}} requires a validator to reject any certificate bearing more than one URI SAN,
whatever its contents. Metadata must go somewhere a relying party will not mistake for an identifier.

Absent such a mechanism, a conforming X.509-based Identity Credential carries the identifier alone:

~~~
X509v3 Basic Constraints: critical
    CA:FALSE
X509v3 Key Usage: critical
    Digital Signature
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication
X509v3 Subject Alternative Name: critical
    URI:spiffe://example.com/agent/a7f3c1a24b904d61
~~~

The identifier is opaque, satisfying {{identifier-role}}, but none of the metadata of {{reuse}} can be
expressed. This is approach 4 below in practice, and it is what deployments using X.509 credentials get
until one of the following is chosen.

Candidate approaches:

1. A single non-critical certificate extension, identified by an OID assigned for this purpose,
   carrying a structured encoding of the metadata defined in {{reuse}}.
2. Separate extensions per attribute.
3. Attribute certificates {{RFC5755}}, which separate attributes from the identity certificate by
   construction, at the cost of a second object to distribute and validate.
4. No X.509 carriage in this document, restricting metadata to JWT-based credentials.

See {{open-issues}} item 2.

## Consistency Across Formats {#consistency}

Where an Issuer issues both JWT-based and X.509-based Identity Credentials for the same Logical Agent,
the metadata asserted in each MUST be consistent, so that a party able to choose between formats cannot
obtain a more favorable authorization outcome by choosing one. Where the two formats cannot express
the same metadata, the Issuer MUST omit the metadata it cannot express consistently rather than assert
divergent values.

# Relationship to Other Work {#relationship}

The RFCs this document profiles are described where they are used. What follows locates it among the
drafts it neighbors.

{{I-D.ietf-wimse-identifier}}:
: Defines the identifier. This document defines what does not go in it and where those attributes go
  instead. It introduces no new identifier syntax.

{{I-D.ietf-wimse-arch}}:
: Provides the architectural frame within which identity credentials are issued and consumed.

{{I-D.ietf-wimse-workload-creds}}:
: Normative. Defines the WIT and WIC that carry the metadata specified here, fixes `sub` as the Workload
  Identifier, and sets the rules for adding claims to a WIT that {{jwt}} profiles.

{{I-D.ietf-wimse-aims}}:
: The WIMSE framework for agent identity, and the closest neighbor to this document. It requires
  exactly one identifier per agent (see {{uniqueness}}) and locates per-request delegation in the OAuth
  access token (see {{human}}). This document is a narrower companion: AIMS establishes that an agent has
  one identifier and is authorized through OAuth, while this document specifies what an Identity Credential
  may assert about that agent and what must not be encoded in the identifier.

# Security Considerations {#security}

## Dependence on Identifier Uniqueness {#binding}

Metadata is bound to the agent only through the identifier that the same credential asserts, so all the
reasoning here rests on {{uniqueness}}. Sharing an identifier does two kinds of damage. Metadata
asserted over a shared identifier is worse than no metadata, because it positively describes an agent
that may not be the caller. And every grant made to a shared identifier accrues to all the agents
holding it, so each agent's effective authority is the union of its co-tenants'. Conformance to
{{uniqueness}} is what makes least privilege expressible at all.

## Strength of the Issuance Decision {#issuance}

An Issuer asserting metadata is making a claim it must be competent to make. If it distinguishes
Logical Agents, or determines their group and role, on properties the agent controls (a self-reported
name, a command-line argument, a writable filesystem path, an executable name it can choose), then any
agent able to reach the Issuer can obtain another agent's identifier and metadata. This converts a
shared-identifier problem into an impersonation problem, which is worse, because the audit record then
positively names the wrong agent.

An Issuer MUST NOT determine an Agent Identifier or Agent Metadata solely from properties the
requesting agent self-reports. Beyond that, Issuers SHOULD determine both from properties the agent
cannot alter within its own privilege level. This document does not define what qualifies, since the
available properties depend on the platform and range from hardware-rooted attestation through
kernel-observed process properties to orchestrator-asserted labels. Whichever an Issuer relies on is
security-relevant configuration and warrants the same review as policy.

## Identity Credentials as Capabilities {#capability}

Metadata that expresses authority converts an identity credential into a capability. Three consequences
motivate {{permissions}}. They do not depend on the credential being a bearer token: a WIT is bound to the
workload's key and cannot be used as one
({{Section 5.1 of I-D.ietf-wimse-workload-creds}}), where a JWT-SVID is presented as one
{{SPIFFE-JWT-SVID}}, and the consequences below hold in both cases.

Lifetime mismatch:
: A permission revoked at the authorization server remains asserted by every unexpired credential
  carrying it. Identity Credential lifetimes are chosen for identity freshness, not for permission
  freshness.

Two authorities:
: If both the Identity Credential and the relying party's policy assert what an agent may do, the
  effective policy is whichever is consulted, and the deployment has two sources of truth for one
  decision.

Blast radius:
: An identity credential is presented to every relying party the agent contacts. A credential enumerating
  permissions discloses the agent's full authority to each of them, including those with no need to
  know it.

## Attribute Staleness {#staleness}

Because metadata is asserted at issuance, it is as fresh as the credential's lifetime. Deployments
requiring rapid attribute revocation SHOULD constrain credential lifetimes accordingly rather than rely
on relying parties to re-resolve attributes out of band.

# Privacy Considerations {#privacy}

Asserting an associated human principal per {{human}} places an identifier for a person into a
credential presented to every relying party the agent contacts, and typically into the audit records of
each. Where the credential is an X.509 certificate, it may additionally be transmitted during TLS
handshakes and retained by intermediaries.

Issuers SHOULD assert a human principal only where relying parties require it, SHOULD prefer an opaque
pseudonymous identifier to a directly identifying one such as an email address, and SHOULD scope
credentials carrying a human principal to the relying parties that need it.

How that scoping is achieved depends on the format, and the obvious mechanism is not always available. A
JWT-SVID can be narrowed by audience restriction, and {{SPIFFE-JWT-SVID}} already recommends a single
narrowly scoped `aud` value. A WIT has no `aud` claim at all, being bound to the workload's key rather
than to a recipient, so an Issuer can limit exposure only by issuing a distinct credential per relying
party, by shortening the credential's lifetime, or by omitting the human principal.

# IANA Considerations {#iana}

This document has no IANA actions. The claims profiled in {{reuse}} are already registered by
{{RFC9068}} in the JSON Web Token Claims registry, and this document defines no new values for them.

--- back

# Open Issues {#open-issues}
{:numbered="false"}

To be resolved with the working group, and removed before publication.

1. **Whether a durable human association belongs in an Identity Credential ({{human}}).** The per-request
   case is settled: it belongs in the access token, per
   {{Section 10.3 of I-D.ietf-wimse-aims}}. What remains is whether a permanent
   "this agent was provisioned for this person" association is an attribute worth asserting at issuance,
   and if so whether it justifies a new registered claim. Deciding not to is a legitimate outcome and
   would remove the {{privacy}} exposure entirely.
2. **X.509 carriage ({{x509}}).** Which of the four candidate approaches to take, and prior to that
   whether this document should cover X.509 at all rather than leaving it to a companion document.
3. **Value encoding for `groups` ({{reuse}}).** {{RFC7643}} defines `groups` as a complex multi-valued
   attribute derived from SCIM `Group` resources, while `roles` and `entitlements` are effectively
   string labels. {{RFC9068}} does not say how the complex form maps into a JWT claim. The interim rule
   in {{reuse}} (emit strings, accept objects with a `value` sub-attribute) needs either confirming
   or replacing, and the question may be better raised against {{RFC9068}} than answered here.
4. **Whether `entitlements` is the right line to draw** between attribute and grant in
   {{permissions}}, or whether the document should exclude authority-bearing metadata entirely.
5. **Terminology alignment.** "Logical Agent", "Execution Instance", and "Identity Credential" are
   introduced here. If equivalent terms exist in {{I-D.ietf-wimse-arch}} or
   {{I-D.ietf-wimse-aims}}, these should defer to them. In particular, "Identity Credential" may be
   unnecessary: WIT and WIC are defined terms, and the abstraction is only needed to also cover SVIDs.
6. **Whether a relying party needs a way to know which metadata an Issuer is authoritative for**, or
   whether that is deployment configuration. This is the {{issuance}} question seen from the consuming
   side.

# Acknowledgments
{:numbered="false"}

This document restates for agent identity an argument the PKIX community made in {{RFC5755}}, and that
{{I-D.ietf-wimse-identifier}} already makes for workload identifiers. The authors thank the WIMSE
working group for the discussion that prompted it.
