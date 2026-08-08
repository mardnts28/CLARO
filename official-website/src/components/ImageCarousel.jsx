import './ImageCarousel.css';

// Discover all images directly in official-website/images/ (excluding developers/)
const imageModules = import.meta.glob('/images/*.{png,jpg,jpeg,webp}', { eager: true, import: 'default' });

const discoveredImages = Object.entries(imageModules)
  .filter(([path]) => !path.includes('/developers/'))
  .map(([_, url]) => url);

// Fallback list of relative image paths directly in official-website/images/
const fallbackImages = [
  'images/707445134_1104459576087616_3251670822965754775_n.jpg',
  'images/708393614_1700340370993983_5531061399465061843_n.jpg',
  'images/708516964_1319857226913913_7251059276085937019_n.jpg',
  'images/708889846_2089075634980844_8372186983577888896_n.jpg',
  'images/709762375_1668970424424606_4203831059844906161_n.jpg',
  'images/710225136_944395981981964_6136114281010016291_n.jpg',
  'images/711405445_1679269943295345_9127255840032732727_n.jpg',
  'images/714630361_27060344500301354_2039133914264788075_n.jpg',
  'images/716109908_1708248893639215_3962947634278828162_n.jpg',
  'images/717167838_1361378055849416_4647591203768236183_n.jpg',
  'images/718086251_1765891208156795_12378188322112497_n.jpg',
  'images/719519170_1500739295131975_2073056133594742672_n.jpg',
  'images/720048801_1329827405785357_6922555382493145800_n.jpg',
  'images/720467282_1007575541632489_5654987228338622032_n.jpg',
  'images/720804830_1017359180804413_6267318907432403943_n.jpg',
  'images/CLARO (1).png',
  'images/CLARO (2).png'
];

const imagesToDisplay = discoveredImages.length > 0 ? discoveredImages : fallbackImages;

export default function ImageCarousel() {
  // Duplicate array to achieve a seamless, continuous infinite scroll loop
  const marqueeList = [...imagesToDisplay, ...imagesToDisplay];

  return (
    <div className="image-carousel-container" aria-label="Auto-scrolling project gallery">
      <div className="image-carousel-track">
        {marqueeList.map((src, index) => (
          <div className="carousel-image-card" key={index}>
            <img
              src={src}
              alt={`CLARO Project Gallery ${index + 1}`}
              className="carousel-image"
              loading="lazy"
            />
          </div>
        ))}
      </div>
    </div>
  );
}
