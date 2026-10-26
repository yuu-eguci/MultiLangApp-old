using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace MultiLangApp.Controllers
{
    public class HomeController : Controller
    {
        private static readonly log4net.ILog logger = log4net.LogManager.GetLogger("SampleLogger");

        public ActionResult Index()
        {
            // Client IP addresses are personal data, so the access log keeps only the culture.
            logger.Info("This is the access log! "
                        + "CurrentUICulture: " + System.Threading.Thread.CurrentThread.CurrentUICulture);

            // 手動で CurrentUICulture を切り替える場合の記述。
            // System.Threading.Thread.CurrentThread.CurrentUICulture = new System.Globalization.CultureInfo("en-GB");
            return View();
        }

        public ActionResult About()
        {
            ViewBag.Message = "Your application description page.";

            return View();
        }

        public ActionResult Contact()
        {
            ViewBag.Message = "Your contact page.";

            return View();
        }
    }
}