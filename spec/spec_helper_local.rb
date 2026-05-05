# frozen_string_literal: true

# Register a stub powershell exec provider so that Exec resources with
# provider => 'powershell' (used in Windows-targeted manifests) compile
# correctly on Linux CI runners where the provider is not available.
Puppet::Type.type(:exec).provide(:powershell, parent: :posix) do
  desc 'Stub powershell provider for rspec testing on non-Windows platforms.'

  def run(_command, _options = {})
    # no-op stub
  end

  def checkexe(_command)
    # no-op stub
  end

  def validatecmd(_command)
    true
  end
end
