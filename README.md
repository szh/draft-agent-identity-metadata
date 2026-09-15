# Agent Identity Metadata

This is the working area for the individual Internet-Draft, "Agent Identity Metadata".

* [Editor's Copy](https://szh.github.io/draft-agent-identity-metadata/#go.draft-heigh-wimse-agent-identity-metadata.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-heigh-wimse-agent-identity-metadata)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-heigh-wimse-agent-identity-metadata)
* [Compare Editor's Copy to Individual Draft](https://szh.github.io/draft-agent-identity-metadata/#go.draft-heigh-wimse-agent-identity-metadata.diff)

## What this draft says

An agent's group, its role, and the human principal it acts for all have to reach a relying party
somehow. The identifier is the one field guaranteed to get there, so it's the path of least resistance:

```text
spiffe://example.com/ns/prod/team/payments/role/admin/agent/reconciler
```

...and have relying parties parse path components. This draft says don't: an identifier denotes an
agent and carries no relying-party-meaningful semantics, while everything *about* the agent travels as
metadata in the identity document (JWT or X.509) that asserts it.

Six reasons the encoding is unsound (§3.1): path semantics aren't guaranteed parseable, identifiers
and attributes have different lifetimes, cardinality becomes a cross product, authorization degrades
to string matching, the identifier is the most widely exposed field in the system, and the authority
for a name isn't necessarily the authority for a role.

Where claims already exist, the draft **profiles them rather than minting new ones** — `groups`,
`roles` and `entitlements` are already IANA-registered by RFC 9068 with SCIM (RFC 7643) semantics.

## Status

**Pre-submission -00.** Not yet submitted to the IETF. Under active drafting by Shlomo Heigh and Joe Salowey.

Intended status is **Standards Track**, because the draft places normative requirements on Issuers and
relying parties and may yet define a claim or an X.509 extension.

This stays a **separate document** rather than material folded into `draft-ietf-wimse-aims`. AIMS is
framework-shaped and Informational; the requirements here are narrow, normative and directed at Issuers.
§6 states the relationship, and the only real overlap (§4.4) cites AIMS rather than restating it.

Open issues live in the draft's "Open Issues" appendix. The one that needs deciding first:

1. **X.509 carriage (§5.2).** JWT is trivial; X.509 has no claims set. Four candidate approaches
   listed, none chosen — and the obvious shortcut of a second SubjectAltName URI is already closed:
   `workload-creds` §4 forbids a second URI SAN carrying a workload identifier, and the SPIFFE
   X.509-SVID spec goes further, requiring validators to *reject* any certificate with more than one
   URI SAN at all. Until this is settled, X.509 deployments get the identifier and no metadata.

The `sub` question is **closed**: `workload-creds` §4 fixes the WIT's `sub` as the Workload Identifier,
and AIMS §10.3 puts the on-behalf-of party in the *access token's* `sub`. Two documents, no conflict.
What remains open is only whether a *durable* human association belongs in the identity document at all.

## Related work

| Document | Relationship |
| --- | --- |
| [`draft-ietf-wimse-identifier`](https://datatracker.ietf.org/doc/draft-ietf-wimse-identifier/) (-03) | Normative. Defines the identifier; this draft defines what does *not* go in it. |
| [`draft-ietf-wimse-workload-creds`](https://datatracker.ietf.org/doc/draft-ietf-wimse-workload-creds/) (-02) | Normative. Defines the WIT and WIC that carry this metadata, fixes `sub`, and sets the rules for adding claims. |
| [RFC 9068](https://www.rfc-editor.org/rfc/rfc9068.html) / [RFC 7643](https://www.rfc-editor.org/rfc/rfc7643.html) | Normative. Source of the `groups` / `roles` / `entitlements` claims. |
| [`draft-ietf-wimse-aims`](https://datatracker.ietf.org/doc/draft-ietf-wimse-aims/) (-00) | Closest neighbor. The WIMSE agent-identity framework; this draft is a narrower companion (§6). |
| [`draft-ietf-wimse-arch`](https://datatracker.ietf.org/doc/draft-ietf-wimse-arch/) (-08) | Architectural frame. |
| [SPIFFE JWT-SVID](https://github.com/spiffe/spiffe/blob/main/standards/JWT-SVID.md) / [X.509-SVID](https://github.com/spiffe/spiffe/blob/main/standards/X509-SVID.md) | Informative. The non-WIMSE identity documents the draft also covers; source of the one-URI-SAN rule. |
| [RFC 8693](https://www.rfc-editor.org/rfc/rfc8693.html) | Informative. Delegation model (`act`, `may_act`). |
| [RFC 5755](https://www.rfc-editor.org/rfc/rfc5755.html) | Prior art: PKIX attribute certificates solved the same separation. |

Two drafts cited in earlier revisions have moved: `draft-ietf-wimse-s2s-protocol` was **replaced**,
split into `workload-creds`, `http-signature`, `mutual-tls` and `wpt`; and `draft-klrc-aiagent-auth`
was **adopted** by WIMSE and is now `draft-ietf-wimse-aims`.

## Contributing

See the
[guidelines for contributions](https://github.com/szh/draft-agent-identity-metadata/blob/main/CONTRIBUTING.md).

Contributions can be made by creating pull requests.

## Command Line Usage

Formatted text and HTML versions of the draft can be built using `make`.

```sh
$ make
```

Command line usage requires that you have the necessary software installed. See
[the instructions](https://github.com/martinthomson/i-d-template/blob/main/doc/SETUP.md).

`make` provisions what it needs on first run: it clones `i-d-template` into `lib/`, installs gems under
`lib/.gems/`, and builds a Python virtualenv at `lib/.venv/` containing `xml2rfc`. Ruby is the one thing it
will not install for you — `lib/Gemfile.lock` pins Bundler 2.6.9, which requires Ruby 3.1 or newer, so
macOS system Ruby (2.6) fails with a bundler activation error before `kramdown-rfc` ever runs. `mise.toml`
pins Ruby 3 for this repo, so with mise active in your shell `make` works from a clean checkout. CI builds
the draft on every push regardless.

`TEXT_PAGINATION := true` is set in the `Makefile` so the built `.txt` carries formfeeds and an Expires
line, matching what the datatracker renders. Without it `idnits` reports ten spurious nits.

To lint before submitting (`brew install idnits`), check against a versioned filename — `idnits` derives
expectations from the name:

```sh
$ make && cp draft-heigh-wimse-agent-identity-metadata.txt /tmp/draft-heigh-wimse-agent-identity-metadata-00.txt
$ idnits /tmp/draft-heigh-wimse-agent-identity-metadata-00.txt
```

The expected clean result is three errors and one warning, none of them defects. The errors are
`FILENAME_DOCNAME_MISMATCH` (the `docname` is `-latest` by `i-d-template` convention), and two
`POSSIBLE_DOWNREF`s for the normative references to `wimse-identifier` and `wimse-workload-creds`, which
resolve when those drafts become RFCs. The warning is `PREFER_BCP14_REF`; `draft-ietf-wimse-arch` carries it too, and kramdown-rfc's
`bcp14-tagged-bcp14` "fix" mentions RFC 2119 and RFC 8174 without generating reference entries for
either, which is worse.
