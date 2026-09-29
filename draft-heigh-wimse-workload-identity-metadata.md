---
title: "Workload Identity Metadata"
abbrev: "Workload Identity Metadata"
category: std

docname: draft-heigh-wimse-workload-identity-metadata-latest
submissiontype: IETF
number:
date:
consensus: true
v: 3
area: "Security"
workgroup: "Workload Identity in Multi System Environments"
keyword:
 - workload identity
 - agent identity
 - identifier
 - metadata
 - delegation
venue:
  group: "Workload Identity in Multi System Environments"
  type: "Working Group"
  mail: "wimse@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/wimse/"
  github: "szh/draft-agent-identity-metadata"
  latest: "https://szh.github.io/draft-agent-identity-metadata/draft-heigh-wimse-workload-identity-metadata.html"

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

informative:
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

This document specifies metadata attributes associated with a workload's identity that are used for
auditing, authorization, accounting, and other purposes. It profiles existing claims for group
membership, roles, and entitlements in JWT-based Workload Identity Credentials, including WIMSE
Workload Identity Tokens (WITs), and discusses carriage in X.509-based credentials.

This document defines the separation between identifier and metadata, and profiles existing claims for
expressing workload attributes. It distinguishes these attributes and durable principal associations
from per-request delegation and grants such as scopes, and states the requirements that make the
separation sound, including identifier uniqueness.

The document applies to workloads generally, including services, batch and continuous integration
jobs, serverless functions, and AI agents. Agentic use cases are discussed separately.

--- middle

# Introduction {#intro}

An identifier denotes a workload. Metadata describes it. These are different things with different
lifetimes, different authorities, and different exposure, and conflating them causes concrete harm.

Encoding them in the identifier is common practice, but it produces identifiers with structured paths
that relying parties are then expected to parse and authorize on. Deployments that need to authorize
on a workload's group, role, or owner frequently encode those attributes into the identifier,
producing identifiers of the form:

~~~
spiffe://example.com/ns/prod/team/payments/role/reconciler/service/reconciliation
~~~

Relying parties are then expected to parse path components and authorize on them. This appears to
work, and it is the path of least resistance because the identifier is the one field guaranteed to
reach the relying party. It is nonetheless unsound, for reasons developed in {{pollution}}: the
identifier format does not promise parseable semantics, attributes and identifiers have different
lifetimes, and the identifier is the most widely exposed field in the system.

This document specifies the alternative. An identifier denotes the workload or workload instance
selected by the deployment's identity model; a relying party does not derive attributes from its
structure. This document profiles metadata carried in the Workload Identity Credential that asserts
the identifier: a JWT such as a WIMSE Workload Identity Token
{{!WIMSE-CREDS=I-D.ietf-wimse-workload-creds}} or a JWT-SVID. Carriage in X.509 certificates remains an open issue.

Where suitable claims already exist, this document profiles them rather than defining new ones. Group,
role, and entitlement claims are already registered {{!OAUTH-JWT=RFC9068}} with semantics drawn from SCIM
{{!SCIM-CORE=RFC7643}}, and delegation is already expressible {{?OAUTH-TOKEN-EXCHANGE=RFC8693}}.

The separation between identifiers and workload attributes applies across workload types. A replicated
service can change team membership without changing its identifier. A continuous integration (CI) job
or a batch job can have a role independent of the worker on which it runs. A serverless function can
retain its workload identifier across invocations, while a deployment requiring separate attribution
can assign identifiers to individual instances.

AI agents have the same needs, with additional considerations discussed in {{agentic}}.

## Scope

In scope:

* the separation between identifier and metadata, and requirements enforcing it;
* metadata for workload group, role, and entitlements, and consideration of durable principal
  associations;
* how metadata is carried in JWT-based and X.509-based identity credentials;
* the identifier uniqueness requirements that the separation depends on.

Out of scope:

* the identifier format itself, which is {{!WIMSE-IDENTIFIER=I-D.ietf-wimse-identifier}};
* conveying metadata in an object separate from the identity credential;
* authentication and transport protocols;
* how a relying party reaches an authorization decision from metadata;
* verification of the identity credentials, for which see
  {{Section 3 of WIMSE-CREDS}}, {{SPIFFE-JWT-SVID}}, and {{SPIFFE-X509-SVID}}.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

The terms Workload, Workload Instance, and Workload Identity Credential are used as defined in
{{Section 2 of !WIMSE-ARCH=I-D.ietf-wimse-arch}}. Workload Identifier and Issuer are used as defined in
{{Section 3 of WIMSE-IDENTIFIER}}. References to credential issuers follow the credential
issuance roles described in {{WIMSE-CREDS}} and the applicable SPIFFE
specifications. In particular, {{Section 5.1 of WIMSE-CREDS}} identifies the
Identity Server as the issuer of a WIT. This document does not require identifier assignment,
credential issuance, and metadata determination to be performed by the same entity.

A workload can have multiple concurrent instances. A Workload Identifier can identify a logical
workload or a particular instance, according to deployment policy; this document does not require a
separate identifier for each process, replica, job, or invocation.

Workload Metadata:
: Attributes of the workload or workload instance denoted by a Workload Identifier, distinct from
  that identifier, asserted for authorization, audit, accounting, and similar purposes.

The Workload Identity Credentials discussed here include WIMSE Workload Identity Tokens (WITs) and
Workload Identity Certificates (WICs), defined in {{WIMSE-CREDS}}, and SPIFFE
JWT-SVIDs {{SPIFFE-JWT-SVID}} and X.509-SVIDs {{SPIFFE-X509-SVID}}. SPIFFE refers to these objects as
identity documents; this document uses "credential" throughout, consistent with WIMSE terminology.

# The Separation Principle {#separation}

## Why Attributes Are Not Encoded in Identifiers {#pollution}

The reasons below are independent: a solution that mitigates one still faces the others.

Path semantics are not guaranteed.
: {{Section 4.2 of WIMSE-IDENTIFIER}} states that path contents are "deployment-specific and
  are interpreted according to the scheme, policy of the trust domain, as implemented by the issuer or
  issuers authorized for that trust domain", and {{Section 4.3 of WIMSE-IDENTIFIER}} requires
  that consumers "MUST compare and authorize Workload Identifiers using the complete URI, rather than
  relying only on individual components such as the path". A relying party parsing path components to
  recover a role is doing something the identifier format does not support.

Lifetimes differ.
: A Workload Identifier is stable; it is the thing audit records and authorization grants refer to over
  time. Attributes are mutable: a workload is reassigned to another team, its role narrows, its
  owner changes. Encoding a mutable attribute in a stable identifier forces a choice between two bad
  outcomes. Re-identifying the workload whenever an attribute changes breaks every grant and every
  historical audit record that named it. Leaving the identifier alone lets it assert something that is
  no longer true.

Cardinality multiplies.
: Encoding *n* attributes produces an identifier space that is their cross product. Every combination
  of group, role, and owner becomes a distinct identifier requiring its own registration, its own
  grants, and its own policy entries.

Authorization becomes string matching.
: Policy written against path prefixes couples authorization to a naming convention. Renaming a team
  silently changes who is authorized, and the coupling is invisible at both the policy and the naming
  end. {{Section 7.6 of WIMSE-IDENTIFIER}} advises consumers against exactly this, warning
  that prefix matching "may lead to incorrect authorization".

Exposure is maximal.
: The identifier is the most widely visible field in the system. It appears in audit logs across every
  component on the call path, in certificate subject alternative names transmitted during TLS
  handshakes, and in diagnostic output. Attributes embedded there are disclosed wherever the
  identifier travels, which is everywhere. {{Section 7.5 of WIMSE-IDENTIFIER}} raises the
  same concern for descriptive paths generally. It is most acute for human identity; see {{privacy}}.

Authority differs.
: The authority competent to assign an identifier is not necessarily the authority competent to assert
  a role or a principal association. Encoding both in one string requires a single issuer to be
  authoritative for all of it.

WIMSE has already applied this reasoning to a narrower case.
{{Section 4 of WIMSE-CREDS}} requires that where a deployment has several labels for
one runtime, additional correlation "MUST NOT be encoded as a second workload identifier", directing
deployments to additional claims instead. This document generalizes that reasoning from correlation data
to workload attributes.

PKIX addressed the same tension earlier, separating attributes from identity certificates into attribute
certificates {{?INET-CERT=RFC5755}}. The mechanism saw limited deployment, but the analysis holds and the
separation it describes is the one specified here.

## Content of the Workload Identifier {#identifier-role}

A Workload Identifier MUST unambiguously denote the workload or workload instance selected by the
deployment's identity model. Multiple instances MAY share an identifier when they are intended to be
treated as the same service for authentication, authorization, and auditing, as specified in
{{Section 4.2 of WIMSE-IDENTIFIER}}. A relying party requiring the subject's group, role, or
principal association MUST obtain it from Workload Metadata rather than infer it from the identifier.
Permissions and scopes are addressed in {{permissions}}.

An Issuer MAY use structured paths for administrative convenience, such as delegation of naming
authority within a trust domain or operator legibility. Where it does, the structure is not a contract: a
relying party MUST NOT derive authorization-relevant meaning from any component of a Workload
Identifier.

## Content of the Workload Identity Credential {#document-role}

A Workload Identity Credential asserts a Workload Identifier and MAY assert Workload Metadata
describing the workload or workload instance that identifier denotes. Metadata in a Workload
Identity Credential is asserted by the credential issuer and inherits the credential's signature,
its validity period, and its trust path. That is what distinguishes it from an attribute the
workload asserts about itself at the application layer.

## Why Metadata Travels With the Credential {#in-band}

A relying party needing an attribute has three places to obtain it: the Workload Identifier, a lookup
service, or the Workload Identity Credential. {{pollution}} rules out the first. A lookup service is
deployable but requires a record per workload, written before the workload's first authenticated
request; a workload whose record has not been written is indistinguishable from an unknown one.

In-credential carriage requires no such record. The credential issuer's configuration is
per-category rather than per-workload: a new workload in a known category costs no new entry; only a
genuinely new category requires credential issuer configuration.

# Workload Metadata {#metadata}

## Reuse of Existing Claims {#reuse}

This document does not define new claims for group, role, or permission where registered claims exist.
{{Section 7.2.1 of OAUTH-JWT}} registers `groups`, `roles`, and `entitlements` in the JSON Web Token
Claims registry, referring for their definitions to {{Section 4.1.2 of SCIM-CORE}}. A Workload Identity
Credential expressing a workload's group, role, or entitlements MUST use those claims.

| Attribute | Claim | Source |
|---|---|---|
| Group membership | `groups` | {{OAUTH-JWT}}, {{SCIM-CORE}} |
| Role | `roles` | {{OAUTH-JWT}}, {{SCIM-CORE}} |
| Coarse entitlements | `entitlements` | {{OAUTH-JWT}}, {{SCIM-CORE}} |

Two aspects of this reuse need stating explicitly.

The subject is the workload.
: {{Section 2.2.3.1 of OAUTH-JWT}} motivates these claims in terms of the resource owner, citing
  "resource owner memberships in roles and groups" and "entitlements assigned to the resource owner",
  and {{SCIM-CORE}} defines them as attributes of a SCIM `User`. This document applies them to the subject of
  the Workload Identity Credential, which is a workload or workload instance rather than a person.
  The registrations themselves are subject-neutral, so no conflict arises, but a relying party MUST
  interpret these claims as describing the workload or workload instance denoted by `sub` and
  MUST NOT interpret them as describing an associated principal ({{principal}}), where one is asserted.

Value encoding is not fully determined.
: {{SCIM-CORE}} specifies no vocabulary or syntax for `roles` and `entitlements`, expecting a role
  value to be "a String or label representing a collection of entitlements". It describes `groups`
  differently: as a multi-valued complex attribute with `value` and `type` sub-attributes and
  canonical types "direct" and "indirect", derived from SCIM `Group` resources that have no
  counterpart here. Neither {{OAUTH-JWT}} nor this document settles whether `groups` in a Workload
  Identity Credential is an array of strings or an array of objects. Until it is settled, a
  credential issuer SHOULD encode all three claims as arrays of strings, and a relying party SHOULD
  accept an array of objects bearing a `value` sub-attribute as equivalent to the array of those
  `value` strings. See {{open-issues}} item 3.

Values are otherwise trust-domain specific, and this document defines no vocabulary. A relying party
MUST treat an unrecognized value as conveying no authority rather than as a wildcard.

## Associated Principal {#principal}

A workload can have a durable association with a person, an organization, or another workload, such as
an owner or operator. It can also act on behalf of a principal for a particular request. These are
different relationships: an ownership or operational association does not itself confer authority to
act on that principal's behalf. Some workloads operate autonomously and have no delegated principal
for a request.

{{Section 4 of WIMSE-CREDS}} requires each Workload Identity Credential to carry
exactly one Workload Identifier, in `sub` for a WIT. An associated principal does not replace that
identifier. The credential identifies the workload, even when a separate authorization artifact
describes a delegation relationship.

Applying the distinction of {{permissions}}, per-request delegation belongs in the authorization
context, such as an OAuth access token, rather than in Workload Metadata. {{OAUTH-TOKEN-EXCHANGE}} provides
mechanisms for expressing delegation in tokens. The particular access-token claims depend on the
applicable authorization profile; the AI agent profile is discussed in {{agentic}}.

Whether a durable principal association is an attribute worth asserting in a Workload Identity
Credential, and how it should be represented, remains open. This document defines no claim for that
association; see {{open-issues}} item 1. Where the associated principal is a person, asserting it is
subject to {{privacy}}.

## Permissions and Scopes {#permissions}

Deployments frequently want a workload's permissions in its Workload Identity Credential. This document
distinguishes two cases and treats them differently, because they are not the same kind of statement.

Attributes of the subject, such as group, role, and coarse entitlements, describe what the workload
is. They are relatively stable, they are meaningful independent of any particular relying party, and
the credential issuer is plausibly authoritative for them. These belong in the Workload Identity
Credential per {{reuse}}.

Grants, such as scopes and fine-grained permissions, describe what the workload may do at a given
resource at a given moment. They are relationship-specific, they change faster than an identity
credential's lifetime, and the authority for them is the resource owner or an authorization server,
not the credential issuer.

Accordingly, a Workload Identity Credential MAY carry coarse entitlements per {{reuse}}, but SHOULD NOT carry
resource-specific scopes or fine-grained permissions. Where a deployment carries them anyway, a relying
party MUST NOT treat them as authoritative for an authorization decision, and MUST obtain authorization
from its own policy or from an authorization server. {{capability}} gives the reasoning.

## Identifier Uniqueness {#uniqueness}

The separation principle depends on the identifier unambiguously denoting its subject at the
granularity selected by the deployment. Where workloads intended to be separately authorized,
revoked, or attributed share an identifier, metadata cannot restore the distinction: a relying party
cannot establish whether workload-specific metadata describes the caller or a co-tenant.

{{Section 4.3 of WIMSE-IDENTIFIER}} requires that issuers
"MUST ensure uniqueness of all Workload Identifiers they assign"; and
{{Section 4.5 of WIMSE-IDENTIFIER}} and {{Section 7.4 of WIMSE-IDENTIFIER}} advise
against reassigning a retired identifier. Sharing is permitted only where the instances "are intended to
be treated as the same workload for the purpose of authentication, authorization, and auditing"
({{Section 4.2 of WIMSE-IDENTIFIER}}). Replicas of a service can satisfy that condition;
workloads requiring separate authorization or attribution do not satisfy it merely because they share
an execution environment. If an identifier denotes a logical workload with multiple instances,
metadata bound only to that identifier MUST describe that workload, rather than properties of one
particular instance that do not apply to the others.

What none of these address is the case that makes the requirement hard to meet in practice:
platforms commonly issue a credential scoped to the execution environment rather than to the
workload, such as an execution role assumed by every workload in a deployment, so the only subject
available to a credential issuer is one shared by several workloads that require distinct
identities. Therefore:

A credential issuer MUST NOT use the subject of a platform-provided execution credential as a
Workload Identifier where that credential is, or may become, available to workloads or instances
that require distinct identities under the deployment's identity model.

Where the platform offers only such a credential, a credential issuer MUST establish by a means not
under the control of the workload which workload or instance is requesting a credential, and MUST
issue a Workload Identity Credential asserting the corresponding Workload Identifier rather than
passing the shared execution credential through. The execution credential MAY be an input to that
determination as evidence of the execution environment; it MUST NOT be the sole input. These
requirements do not prohibit a shared credential for instances intentionally treated as the same
workload.

# Agentic Use Cases {#agentic}

AI agents are workloads to which the metadata model in this document applies. An agent may run as a
long-lived service, an ephemeral task, or multiple concurrent instances. Its group membership, roles,
and entitlements describe the agent identified by the credential. Per-request delegation is a
separate relationship, as discussed in {{principal}}.

Autonomous operation:
: An agent performing scheduled reconciliation can operate under its own workload identity and
  authorization. An owner or operator association, if asserted, does not imply that each action is
  performed on that principal's behalf.

Delegated operation:
: An assistant can act on behalf of a human or another workload for a particular request. Its
  Workload Identity Credential still identifies the agent, while a separate authorization context
  expresses the delegation. The agent's `groups` and `roles` do not become those of the delegating
  principal. {{Section 10.3 of ?WIMSE-AIMS=I-D.ietf-wimse-aims}} describes an OAuth profile in which the agent's
  identifier appears in the access token's `client_id`, and the user or system on whose behalf it
  acts appears in `sub`. That profile does not change the subject of the agent's Workload Identity
  Credential.

Shared execution environments:
: A platform can host several agents in the same process, container, or execution role. Agents that
  require separate authorization or attribution need distinct identifiers under {{uniqueness}};
  shared infrastructure alone does not establish that they are the same workload. Conversely,
  replicas or sessions intentionally treated as instances of the same agent need not acquire
  distinct identifiers solely because they are separate executions.

{{Section 6 of WIMSE-AIMS}} requires an agent participating in that framework to be assigned
exactly one WIMSE identifier. That requirement belongs to the agent framework; this document follows
the general workload and instance identity model of {{WIMSE-IDENTIFIER}}.

# Carrying Metadata in Workload Identity Credentials {#carriage}

## JWT-Based Credentials {#jwt}

Metadata is carried as claims in the JWT {{!JWT=RFC7519}} claims set, using the claims in {{reuse}}. No new
mechanism is required, and the rules for doing so are already established:
{{Section 5.1.2 of WIMSE-CREDS}} permits additional claims in a WIT, requires that a
recipient ignore claims it does not understand, discourages private claim names, and requires that
claims used outside closed environments be registered with IANA. Because the claims in {{reuse}} are
already registered, a Workload Identity Credential expressing workload group, role, or entitlements
satisfies those rules without further action.

The following non-normative examples show Workload Identity Credentials for the reconciliation service
that {{intro}} names with an attribute-bearing identifier. Its replicas share a workload identifier and
the same workload metadata. In each example, the identifier is opaque and the attributes appear only
as claims.

A WIT, whose JOSE header carries `"typ": "wit+jwt"`:

~~~ json
{
  "iss": "https://issuer.example.com",
  "sub": "wimse://example.com/workload/a7f3c1a24b904d61",
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
({{Section 5.1 of WIMSE-CREDS}}). The same workload as a JWT-SVID {{SPIFFE-JWT-SVID}},
which is instead audience-restricted and carries no confirmation claim:

~~~ json
{
  "sub": "spiffe://example.com/workload/a7f3c1a24b904d61",
  "aud": ["spiffe://example.com/service/ledger"],
  "iat": 1757894400,
  "exp": 1757898000,
  "groups": ["team-payments"],
  "roles": ["reconciler"],
  "entitlements": ["ledger-read"]
}
~~~

The metadata is identical across the two formats, as {{consistency}} requires. Two properties of these
examples illustrate what the separation buys. Reassigning the workload to another team
changes `groups` and leaves `sub` untouched, so every existing grant and every historical audit record
that named the workload remains valid and remains accurate. And a relying party that is not authorized to
learn the workload's role can be issued a credential omitting `roles`, without changing the workload's
identifier, because the identifier no longer carries it.

## X.509-Based Credentials {#x509}

X.509 certificates have no equivalent of a claims set, so carrying metadata in one requires a mechanism
this document does not yet specify.

{{Section 6.1 of WIMSE-CREDS}} defines the Workload Identity Certificate, which
carries the Workload Identifier in a single URI SubjectAltName. The obvious approach is therefore
already closed: {{Section 4 of WIMSE-CREDS}} requires that additional correlation
"MUST NOT be encoded as a second workload identifier in the same WIT or WIC", so workload attributes cannot
be carried in a second URI SAN. For an X.509-SVID the constraint is stronger still:
{{SPIFFE-X509-SVID}} requires a validator to reject any certificate bearing more than one URI SAN,
whatever its contents. Metadata must go somewhere a relying party will not mistake for an identifier.

Absent such a mechanism, a conforming X.509-based Workload Identity Credential carries the identifier alone:

~~~
X509v3 Basic Constraints: critical
    CA:FALSE
X509v3 Key Usage: critical
    Digital Signature
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication
X509v3 Subject Alternative Name: critical
    URI:spiffe://example.com/workload/a7f3c1a24b904d61
~~~

The identifier is opaque, satisfying {{identifier-role}}, but none of the metadata of {{reuse}} can be
expressed. This is approach 4 below in practice, and it is what deployments using X.509 credentials get
until one of the following is chosen.

Candidate approaches:

1. A single non-critical certificate extension, identified by an OID assigned for this purpose,
   carrying a structured encoding of the metadata defined in {{reuse}}.
2. Separate extensions per attribute.
3. Attribute certificates {{INET-CERT}}, which separate attributes from the identity certificate by
   construction, at the cost of a second object to distribute and validate.
4. No X.509 carriage in this document, restricting metadata to JWT-based credentials.

See {{open-issues}} item 2.

## Consistency Across Formats {#consistency}

Where a credential issuer issues both JWT-based and X.509-based Workload Identity Credentials for
the same workload or workload instance, the metadata asserted in each MUST be consistent, so that a
party able to choose between formats cannot obtain a more favorable authorization outcome by
choosing one. Where the two formats cannot express the same metadata, the credential issuer MUST
omit the metadata it cannot express consistently rather than assert divergent values.

# Relationship to Other Work {#relationship}

The RFCs this document profiles are described where they are used. What follows locates it among the
drafts it neighbors.

{{WIMSE-IDENTIFIER}}:
: Defines the identifier. This document defines what does not go in it and where those attributes go
  instead. It introduces no new identifier syntax.

{{WIMSE-ARCH}}:
: Provides the architectural frame and the definitions of Workload, Workload Instance, and Workload
  Identity Credential used in this document.

{{WIMSE-CREDS}}:
: Normative. Defines the WIT and WIC that carry the metadata specified here, fixes `sub` as the Workload
  Identifier, and sets the rules for adding claims to a WIT that {{jwt}} profiles.

{{WIMSE-AIMS}}:
: The WIMSE framework for AI agent identity. It establishes identifier and OAuth authorization
  requirements for agents participating in that framework. This document defines metadata for
  workloads generally, including those agents; {{agentic}} describes the relationship without
  imposing the agent framework on other workloads.

# Security Considerations {#security}

## Dependence on Identifier Uniqueness {#binding}

Metadata is bound to its subject through the identifier that the same credential asserts, so the
reasoning here rests on {{uniqueness}}. Sharing an identifier among workloads or instances that require
distinct identities does two kinds of damage. Metadata can describe a different subject from the
caller, and grants made to the shared identifier can accrue to all its holders. Instances
intentionally sharing a workload identity are treated as the same subject; metadata bound only to
that identifier cannot distinguish them for authorization or attribution.

## Strength of the Issuance Decision {#issuance}

A credential issuer asserting metadata is making a claim it must be competent to make. If it
distinguishes workloads, or determines their group and role, on properties the workload controls (a
self-reported name, a command-line argument, a writable filesystem path, an executable name it can
choose), then any workload able to reach the credential issuer can obtain another workload's
identifier and metadata. This converts a shared-identifier problem into an impersonation problem,
which is worse, because the audit record then positively names the wrong workload.

A credential issuer MUST NOT determine a Workload Identifier or Workload Metadata solely from
properties the requesting workload self-reports. Beyond that, credential issuers SHOULD determine
both from properties the workload cannot alter within its own privilege level. This document does
not define what qualifies, since the available properties depend on the platform and range from
hardware-rooted attestation through kernel-observed process properties to orchestrator-asserted
labels not under the deployer's control. Whichever a credential issuer relies on is
security-relevant configuration and warrants the same review as policy.

That requirement constrains the workload, not its deployer. Where a credential issuer maps a
deployment-time record (such as an orchestrator label or workload annotation) to an
authorization-relevant attribute, permission to write that record is permission to grant that
attribute. Deployments SHOULD restrict such write access as tightly as the corresponding
authorization grant, or determine attributes from properties the deployer cannot write.

A deployer can place a workload only in execution environments the platform authorizes them to
access. The namespace a pod runs in, the project a cloud workload is deployed to, and the identity
pool from which it obtains a credential are all properties the platform assigns and the workload
cannot self-report. A credential issuer MAY use such properties as selectors from which to derive
Workload Metadata. Where a property is shared across workloads, it MUST NOT be the sole input to
identifier determination ({{uniqueness}}); it MAY inform which metadata the credential issuer
asserts for workloads that share the environment.

For finer granularity within a shared environment, platform-assigned execution environment
credentials (such as IAM execution roles, managed identities, or service accounts) can
distinguish individual workloads. A credential issuer MAY use such a credential as a selector for
metadata derivation; any use of its subject as a Workload Identifier MUST satisfy {{uniqueness}}.
Deployments SHOULD confirm that the privilege required to assign such a credential exceeds the
privilege required to deploy the workload.

## Workload Identity Credentials as Capabilities {#capability}

Metadata that expresses authority converts an identity credential into a capability. Three consequences
motivate {{permissions}}. They do not depend on the credential being a bearer token: a WIT is bound to the
workload's key and cannot be used as one
({{Section 5.1 of WIMSE-CREDS}}), whereas a JWT-SVID is presented as one
{{SPIFFE-JWT-SVID}}, and the consequences below hold in both cases.

Lifetime mismatch:
: A permission revoked at the authorization server remains asserted by every unexpired credential
  carrying it. Workload Identity Credential lifetimes are chosen for identity freshness, not for permission
  freshness.

Two authorities:
: If both the Workload Identity Credential and the relying party's policy assert what a workload may do, the
  effective policy is whichever is consulted, and the deployment has two sources of truth for one
  decision.

Blast radius:
: An identity credential is presented to every relying party the workload contacts. A credential enumerating
  permissions discloses the workload's full authority to each of them, including those with no need to
  know it.

## Attribute Staleness {#staleness}

Because metadata is asserted at issuance, it is as fresh as the credential's lifetime. Deployments
requiring rapid attribute revocation SHOULD constrain credential lifetimes accordingly rather than rely
on relying parties to re-resolve attributes out of band.

# Privacy Considerations {#privacy}

Asserting an associated human principal per {{principal}} places an identifier for a person into a
credential presented to every relying party the workload contacts, and typically into the audit records of
each. Where the credential is an X.509 certificate, it may additionally be transmitted during TLS
handshakes and retained by intermediaries.

Credential issuers SHOULD assert a human principal only where relying parties require it, SHOULD
prefer an opaque pseudonymous identifier to a directly identifying one such as an email address, and
SHOULD scope credentials carrying a human principal to the relying parties that need it.

How that scoping is achieved depends on the format, and the obvious mechanism is not always
available. A JWT-SVID can be narrowed by audience restriction, and {{SPIFFE-JWT-SVID}} already
recommends a single narrowly scoped `aud` value. A WIT has no `aud` claim at all, being bound to the
workload's key rather than to a recipient, so a credential issuer can limit exposure only by issuing
a distinct credential per relying party, by shortening the credential's lifetime, or by omitting the
human principal.

# IANA Considerations {#iana}

This document has no IANA actions. The claims profiled in {{reuse}} are already registered by
{{OAUTH-JWT}} in the JSON Web Token Claims registry, and this document defines no new values for them.

--- back

# Open Issues {#open-issues}
{:numbered="false"}

To be resolved with the working group, and removed before publication.

1. **Whether a durable principal association belongs in a Workload Identity Credential
   ({{principal}}).** Per-request delegation is separate from workload metadata. What remains is
   whether ownership or operational associations with a person, organization, or another workload
   are attributes worth asserting at issuance, how to distinguish those relationships, and whether
   they justify new registered claims. Associations with people also require the privacy analysis in
   {{privacy}}.
2. **X.509 carriage ({{x509}}).** Which of the four candidate approaches to take, and prior to that
   whether this document should cover X.509 at all rather than leaving it to a companion document.
3. **Value encoding for `groups` ({{reuse}}).** {{SCIM-CORE}} defines `groups` as a complex multi-valued
   attribute derived from SCIM `Group` resources, while `roles` and `entitlements` are effectively
   string labels. {{OAUTH-JWT}} does not say how the complex form maps into a JWT claim. The interim rule
   in {{reuse}} (emit strings, accept objects with a `value` sub-attribute) needs either confirming
   or replacing, and the question may be better raised against {{OAUTH-JWT}} than answered here.
4. **Whether `entitlements` is the right line to draw** between attribute and grant in
   {{permissions}}, or whether the document should exclude authority-bearing metadata entirely.
5. **Whether a relying party needs a way to know which metadata a credential issuer is authoritative for**, or
   whether that is deployment configuration. This is the {{issuance}} question seen from the consuming
   side.
6. **Whether Workload Metadata may be conveyed separately from the Workload Identity Credential.** This document
   deliberately specifies carriage in the Workload Identity Credential only. A separate signed object, bound to
   the Workload Identifier and possibly to a specific Workload Identity Credential, would accommodate an attribute
   authority distinct from the identifier authority and work around the X.509 extension constraints in
   {{x509}}. It would also add a second object to retrieve, validate, and reconcile, require a rule for
   conflicting assertions, and mean a relying party may have to establish authority for two issuers
   rather than one. Whether it belongs here, in a companion document, or nowhere is open.

# Acknowledgments
{:numbered="false"}

This document restates for workload identity an argument the PKIX community made in {{INET-CERT}}, and that
{{WIMSE-IDENTIFIER}} already makes for workload identifiers. The authors thank the WIMSE
working group for the discussion that prompted it.
