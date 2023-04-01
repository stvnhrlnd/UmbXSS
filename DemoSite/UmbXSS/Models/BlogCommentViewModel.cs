using System.ComponentModel.DataAnnotations;
using System.Web.Mvc;

namespace UmbXSS.Models
{
    public class BlogCommentViewModel
    {
        [Required]
        public string Name { get; set; }

        [Required]
        [AllowHtml]
        public string Message { get; set; }
    }
}