# Contributing Guide

We'd love your help!

## How to Contribute

### **Did you find a bug?**

* **Do not open up a GitHub issue if the bug is a security vulnerability. Please [report security issues here]( https://www.splunk.com/en_us/product-security/report.html)**.
* Ensure the bug was not already reported by searching on GitHub under Issues.
* If you're unable to find an open issue addressing the problem, open a new one. Be sure to include a title and clear description, as much relevant information as possible, and a code sample or an executable test case demonstrating the expected behavior that is not occurring.

### **Did you write a patch that fixes a bug?**
* Open a new GitHub pull request against the develop branch with the patch.
* Ensure the pull request description clearly describes the problem and solution. Please create an issue and reference it or the relevant existing issue number as part of the title for the PR.

### **Do you have an idea for a new feature or change an existing one?**
* If you developed a new feature, open a new GitHub pull request against the develop branch with the new feature.
* Ensure the PR description clearly describes the new feature and the benefits. Include the relevant issue number if applicable.
* If you have an idea for a new feature, open a GitHub issue that clearly explains the suggested feature and it’s benefits.

### **Reporting an issue**
We use GitHub Issue Tracking to track issues. If you've found a problem which is not a security risk, check to see if it has already been reported. If not, open a new issue. (See the next section for reporting security issues.)

Your issue report should contain a title and a clear description of the issue at the bare minimum. You should include as much relevant information as possible and should at least post a code sample that demonstrates the issue. Please include relevant unit test cases that show how the expected behavior is not occurring. Your goal should be to make it easy for yourself - and others - to reproduce the bug and figure out a fix.

If possible, create an executable test case. This can be very helpful for others to help confirm, investigate, and ultimately fix your issue.
Project maintainers are responsible for clarifying the standards of acceptable behavior and are expected to take appropriate and fair corrective action in response to any instances of unacceptable behavior.

### **When filing an issue, please include answers for questions below:** 
* What version of Splunk and Kubernetes are you using?
* What operating system and processor architecture are you using?
* What did you do?
* What did you expect to see?
* What did you see instead? 

#### **When filing an issue, please do NOT include:**
* Internal identifiers such as JIRA tickets
* Any sensitive information related to your environment, users, etc.

### **Reporting a security issue**
**Please do not report security vulnerabilities with public GitHub issue reports.  Please [report security issues here]( https://www.splunk.com/en_us/product-security/report.html)**.

### **Verifying existing issues**
We appreciate any help you can provide us with existing issues. Are you able to reproduce a current issue? If so please provide any additional information that might help us to reproduce or fix the issue. If you can contribute a failing test that’s even better.

Please also see [GitHub
workflow](https://github.com/open-telemetry/community/blob/main/CONTRIBUTING.md#github-workflow)
section of general project contributing guide.

### Technical Requirements

* Must follow [Charts best practices](https://helm.sh/docs/topics/chart_best_practices/)
* Must pass CI jobs for linting and installing changed charts with the
  [chart-testing](https://github.com/helm/chart-testing) tool
* Any change to a chart requires a version bump following
  [semver](https://semver.org/) principles. See [Immutability](#immutability)
  and [Versioning](#versioning) below

Once changes have been merged, the release job will automatically run to package
and release changed charts.

### Immutability

Chart releases must be immutable. Any change to a chart warrants a chart version
bump even if it is only changed to the documentation.

### Versioning

The chart `version` should follow [semver](https://semver.org/).

Charts should start at `0.1.0` or `1.0.0`. Any breaking (backwards incompatible)
changes to a chart should:

1. Bump the MAJOR version
2. In the README, under a section called "Upgrading", describe the manual steps
   necessary to upgrade to the new (specified) MAJOR version

### **Contributing code**
If you're planning to submit your change back for inclusion in the main repo, keep a few things in mind:
* You must agree to Splunk's [Contributor License Agreement](http://www.splunk.com/goto/contributions) (CLA) before we can merge any pull requests that you submit. Any contributions that you make to this project will be subject to the terms of this agreement.
* Please review our [Code of Conduct](https://github.com/splunk/sck-otel/blob/main/CODE_OF_CONDUCT.md).
* Fork the repo and create your working branch from the develop branch.
* Include unit tests that fail without your code, and pass with it.
* Update the (surrounding) documentation, examples, and any area that is affected by your contribution.
