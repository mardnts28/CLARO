import './ImageCarousel.css';

// Journey/project gallery images, hosted on Cloudinary.
const imagesToDisplay = [
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704184/708516964_1319857226913913_7251059276085937019_n_wmepny.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704184/708393614_1700340370993983_5531061399465061843_n_ssget9.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704184/707445134_1104459576087616_3251670822965754775_n_ws6okm.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704180/747941040_2242037889887150_3638980499670010176_n_m2jobk.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704180/747718378_1067359415704028_4358389318664291742_n_hw73pi.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704179/720804830_1017359180804413_6267318907432403943_n_xgjuiz.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704179/720467282_1007575541632489_5654987228338622032_n_r8medw.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704178/720048801_1329827405785357_6922555382493145800_n_yhs1ca.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704178/719519170_1500739295131975_2073056133594742672_n_zhuvtf.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704177/718086251_1765891208156795_12378188322112497_n_ywsxnf.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704176/717167838_1361378055849416_4647591203768236183_n_q2cq1m.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704176/716109908_1708248893639215_3962947634278828162_n_bgx3dt.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704176/710225136_944395981981964_6136114281010016291_n_gzfeb9.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704176/711405445_1679269943295345_9127255840032732727_n_scutig.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704175/709762375_1668970424424606_4203831059844906161_n_ifoe6e.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704175/714630361_27060344500301354_2039133914264788075_n_ulxr4c.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704175/709762375_1668970424424606_4203831059844906161_n_1_vlysmu.jpg',
  'https://res.cloudinary.com/dn64fatsy/image/upload/v1786704174/708889846_2089075634980844_8372186983577888896_n_p5yqfl.jpg'
];

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