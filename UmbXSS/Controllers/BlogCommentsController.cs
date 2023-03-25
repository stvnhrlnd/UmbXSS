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
            var model = new BlogCommentViewModel();
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
    }
}