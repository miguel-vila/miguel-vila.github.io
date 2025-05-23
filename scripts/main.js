// Para mostrar y esconder las notas apartes:
$('.note .note-content').toggleClass('hide');

$('.note .aside-header').click(function (ev) {
	var noteContentElement = $(ev.target.parentElement.parentElement).find('.note-content');
	noteContentElement.toggleClass('hide');
});

$(document).ready(function () {
	// Check for saved theme preference or respect OS preference
	const savedTheme = localStorage.getItem('theme');
	const prefersDarkScheme = window.matchMedia('(prefers-color-scheme: dark)');
	
	// Apply saved theme or use OS preference
	if (savedTheme === 'dark' || (!savedTheme && prefersDarkScheme.matches)) {
		$("body").addClass("dark");
		$("#theme-toggle-icon").attr("src", "/images/sun.png");
	} else {
		$("body").removeClass("dark");
		$("#theme-toggle-icon").attr("src", "/images/moon.png");
	}

	// Toggle theme and save preference
	$('.dark__mode>a').on("click", function (e) {
		e.preventDefault();
		if ($("body").hasClass("dark")) {
			$("body").removeClass("dark");
			$(this).find("img").attr("src", "/images/moon.png");
			localStorage.setItem('theme', 'light');
		} else {
			$("body").addClass("dark");
			$(this).find("img").attr("src", "/images/sun.png");
			localStorage.setItem('theme', 'dark');
		}
	});

	// Listen for OS theme changes
	prefersDarkScheme.addEventListener('change', function(e) {
		if (!localStorage.getItem('theme')) {
			if (e.matches) {
				$("body").addClass("dark");
				$("#theme-toggle-icon").attr("src", "/images/sun.png");
			} else {
				$("body").removeClass("dark");
				$("#theme-toggle-icon").attr("src", "/images/moon.png");
			}
		}
	});

	$(".menu__mobile>a").on("click", function (e) {
		e.preventDefault();
		$('.bottom__header > nav').css("top", "0px");
		$('body,html').css("overflow-y", "hidden");
	});
	$('.close__menu').on("click", function (e) {
		e.preventDefault();
		$('.bottom__header > nav').css("top", "-100%");
		$('body,html').css("overflow-y", "initial");
	});
	
	// Initialize responsive images
	makeImagesResponsive();
});

if ($(".post-meta").length) {
	let post = 0;
	$('.post-meta').each(function (index, elem) {
		if (post == 0) {
			if ($(elem).text().length > 7) {
				post = 1;
				$(".post-meta").css("min-width", "105px");
			} else {
				$(".post-meta").css("min-width", "65px");
			}
		}
	});
}

// Helper function to make images responsive
function makeImagesResponsive() {
	// Process all images in the main container
	const contentImages = document.querySelectorAll('.main__container img:not(.responsive-image)');
	contentImages.forEach(img => {
		// Skip images that are already processed or are icons/logos
		if (img.width < 50 || img.height < 50 || img.classList.contains('responsive-image')) {
			return;
		}
		
		// Add responsive class
		img.classList.add('responsive-image');
		
		// If the image has a parent that's a link, we need to style differently
		if (img.parentElement.tagName === 'A') {
			img.parentElement.style.display = 'inline-block';
			img.parentElement.style.maxWidth = '100%';
		}
		
		// Handle book covers specifically
		if (img.classList.contains('book-cover')) {
			// Make sure book covers have proper styling
			img.style.borderRadius = '4px';
		}
	});
	
	// Ensure image articles are properly laid out
	const imageArticles = document.querySelectorAll('.image__article');
	imageArticles.forEach(container => {
		// Check if we're on mobile
		if (window.innerWidth <= 640) {
			// Center the image container on mobile
			container.style.margin = '0 auto 20px auto';
		}
	});
}

// Run on page load and after any AJAX content loads
document.addEventListener('DOMContentLoaded', makeImagesResponsive);
window.addEventListener('load', makeImagesResponsive);
// Also run when window is resized to handle orientation changes
window.addEventListener('resize', makeImagesResponsive);
