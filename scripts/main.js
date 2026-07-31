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
	
	// Turn any <div class="gallery"> into a slideshow
	initGalleries();

	// Initialize responsive images
	makeImagesResponsive();
});

// Progressive-enhancement image gallery / slideshow.
// Author writes:  <div class="gallery"> <img ...> <img ...> </div>
// This wraps the images in a slides container and adds Prev/Next + dot controls.
function initGalleries() {
	$('.gallery').each(function () {
		const $gallery = $(this);
		if ($gallery.data('gallery-init')) {
			return; // already enhanced
		}
		$gallery.data('gallery-init', true);

		// Find images at any depth: Pandoc wraps raw <img> tags in a <p>,
		// so they're usually not direct children of .gallery.
		const $images = $gallery.find('img');
		if ($images.length < 2) {
			return; // nothing to cycle through
		}

		// Mark slides (so makeImagesResponsive skips them), move them into a
		// slides container, and drop any leftover wrappers (e.g. Pandoc's <p>).
		$images.addClass('gallery__slide');
		const $slides = $('<div class="gallery__slides"></div>');
		$images.appendTo($slides);
		$gallery.empty().append($slides);

		// Build the bottom controls: Prev | dots | Next
		const $prev = $('<button type="button" class="gallery__btn gallery__prev" aria-label="Previous image">‹</button>');
		const $next = $('<button type="button" class="gallery__btn gallery__next" aria-label="Next image">›</button>');
		const $dots = $('<div class="gallery__dots"></div>');
		$images.each(function (i) {
			$('<button type="button" class="gallery__dot" aria-label="Go to image ' + (i + 1) + '"></button>').appendTo($dots);
		});

		const $controls = $('<div class="gallery__controls"></div>');
		$controls.append($prev, $dots, $next);
		$gallery.append($controls);

		const $dotButtons = $dots.children();
		let current = 0;

		function show(index) {
			current = (index + $images.length) % $images.length; // wrap around
			$images.removeClass('is-active').eq(current).addClass('is-active');
			$dotButtons.removeClass('is-active').eq(current).addClass('is-active');
		}

		$prev.on('click', function () { show(current - 1); });
		$next.on('click', function () { show(current + 1); });
		$dotButtons.on('click', function () { show($(this).index()); });

		show(0);
	});
}

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
	const contentImages = document.querySelectorAll('.main__container img:not(.responsive-image):not(.gallery__slide)');
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
